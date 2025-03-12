// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IPositionsManager} from "src/interfaces/IPositionsManager.sol";
import {IRewardsManager} from "src/interfaces/IRewardsManager.sol";

import {TestMarket, TestMarketLib} from "test/helpers/TestMarketLib.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

import {PermitHash} from "@permit2/libraries/PermitHash.sol";
import {IAllowanceTransfer, AllowanceTransfer} from "@permit2/AllowanceTransfer.sol";

import {Morpho} from "src/Morpho.sol";
import {PositionsManager} from "src/PositionsManager.sol";
import {RewardsManager} from "src/RewardsManager.sol";
import {UserMock} from "test/mocks/UserMock.sol";
import "./ForkTest.sol";

contract IntegrationTest is ForkTest {
    using SafeTransferLib for ERC20;
    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveDataTestLib for DataTypes.ReserveData;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using TestMarketLib for TestMarket;

    uint256 internal constant INITIAL_BALANCE = 10_000_000_000 ether;

    // AaveV3 base currency is USD, 8 decimals on all L2s.
    uint256 internal constant MIN_USD_AMOUNT = 1e8; // 1$
    uint256 internal constant MAX_USD_AMOUNT = 500_000_000e8; // 500m$

    IMorpho internal morpho;
    IPositionsManager internal positionsManager;
    IRewardsManager internal rewardsManager;

    ProxyAdmin internal proxyAdmin;

    IMorpho internal morphoImpl;
    TransparentUpgradeableProxy internal morphoProxy;

    UserMock internal user;
    UserMock internal promoter1;
    UserMock internal promoter2;
    UserMock internal hacker;

    mapping(address => TestMarket) internal testMarkets;

    uint8 internal eModeCategoryId = uint8(vm.envOr("E_MODE_CATEGORY_ID", uint256(0)));
    address[] internal collateralUnderlyings;
    address[] internal borrowableInEModeUnderlyings;
    address[] internal borrowableNotInEModeUnderlyings;

    function setUp() public virtual override {
        _deploy();

        for (uint256 i; i < allUnderlyings.length; ++i) {
            _createTestMarket(allUnderlyings[i], 0, 33_33);
        }

        _forward(1); // All markets are outdated in Morpho's storage.

        user = _initUser();
        promoter1 = _initUser();
        promoter2 = _initUser();
        hacker = _initUser();

        super.setUp();
    }

    function _label() internal override {
        super._label();

        vm.label(address(morpho), "Morpho");
        vm.label(address(morphoImpl), "MorphoImpl");
        vm.label(address(positionsManager), "PositionsManager");

        vm.label(address(user), "User");
        vm.label(address(promoter1), "Promoter1");
        vm.label(address(promoter2), "Promoter2");
        vm.label(address(hacker), "Hacker");
    }

    function _deploy() internal virtual {
        positionsManager = new PositionsManager();
        morphoImpl = new Morpho();

        proxyAdmin = new ProxyAdmin();
        morphoProxy = new TransparentUpgradeableProxy(payable(address(morphoImpl)), address(proxyAdmin), "");
        morpho = Morpho(payable(address(morphoProxy)));

        morpho.initialize(
            address(addressesProvider),
            eModeCategoryId,
            address(positionsManager),
            Types.Iterations({repay: 10, withdraw: 10})
        );

        rewardsManager = new RewardsManager(address(rewardsController), address(morpho));

        morpho.setRewardsManager(address(rewardsManager));
    }

    function _initUser() internal returns (UserMock newUser) {
        newUser = new UserMock(address(morpho));

        _setBalances(address(newUser), INITIAL_BALANCE);
    }

    function _createForkFromEnv() internal {
        string memory endpoint = vm.envString("FOUNDRY_ETH_RPC_URL");
        uint256 blockNumber = vm.envUint("FOUNDRY_FORK_BLOCK_NUMBER");

        forkId = vm.createSelectFork(endpoint, blockNumber);
    }

    function _initMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor)
        internal
        virtual
        returns (TestMarket storage market, DataTypes.ReserveData memory reserve)
    {
        market = testMarkets[underlying];
        reserve = pool.getReserveData(underlying);

        market.underlying = underlying;
        market.aToken = reserve.aTokenAddress;
        market.variableDebtToken = reserve.variableDebtTokenAddress;
        market.stableDebtToken = reserve.stableDebtTokenAddress;
        market.symbol = ERC20(underlying).symbol();
        market.reserveFactor = reserveFactor;
        market.p2pIndexCursor = p2pIndexCursor;
        market.price = oracle.getAssetPrice(underlying); // Price is constant, equal to price at fork block number.

        (market.ltv, market.lt, market.liquidationBonus, market.decimals,,) = reserve.configuration.getParams();

        market.minAmount = (MIN_USD_AMOUNT * 10 ** market.decimals) / market.price;
        market.maxAmount = (MAX_USD_AMOUNT * 10 ** market.decimals) / market.price;

        // Disable supply & borrow caps for all created markets.
        poolAdmin.setSupplyCap(underlying, 0);
        poolAdmin.setBorrowCap(underlying, 0);
        market.supplyCap = type(uint256).max;
        market.borrowCap = type(uint256).max;

        market.eModeCategoryId = uint8(reserve.configuration.getEModeCategory());
        market.eModeCategory = pool.getEModeCategoryData(market.eModeCategoryId);

        market.isInEMode = eModeCategoryId == 0 || eModeCategoryId == market.eModeCategoryId;
        market.isCollateral = market.getLt(eModeCategoryId) > 0 && reserve.configuration.getDebtCeiling() == 0;
        market.isBorrowable = reserve.configuration.getBorrowingEnabled() && !reserve.configuration.getSiloedBorrowing();

        vm.label(reserve.aTokenAddress, string.concat("a", market.symbol));
        vm.label(reserve.variableDebtTokenAddress, string.concat("vd", market.symbol));
        vm.label(reserve.stableDebtTokenAddress, string.concat("sd", market.symbol));
    }

    function _createTestMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor) internal virtual {
        (TestMarket storage market,) = _initMarket(underlying, reserveFactor, p2pIndexCursor);

        morpho.createMarket(market.underlying, market.reserveFactor, market.p2pIndexCursor);

        // Supply dust to:
        // 1. account for roundings upon borrow or withdraw.
        // 2. make UserConfigurationMap.isUsingAsCollateral() return true (cannot enable the asset as collateral on the pool if Morpho has no aToken).
        _deposit(market.underlying, 10 ** (market.decimals / 2), address(morpho));

        if (market.isCollateral) {
            collateralUnderlyings.push(underlying);

            morpho.setAssetIsCollateral(underlying, true);
        }

        if (market.isBorrowable) {
            if (market.isInEMode) borrowableInEModeUnderlyings.push(underlying);
            else borrowableNotInEModeUnderlyings.push(underlying);
        }
    }

    function _randomCollateral(uint256 seed) internal view returns (address) {
        return collateralUnderlyings[seed % collateralUnderlyings.length];
    }

    function _randomBorrowableInEMode(uint256 seed) internal view returns (address) {
        return borrowableInEModeUnderlyings[seed % borrowableInEModeUnderlyings.length];
    }

    function _randomBorrowableNotInEMode(uint256 seed) internal view returns (address) {
        return borrowableNotInEModeUnderlyings[seed % borrowableNotInEModeUnderlyings.length];
    }

    /// @dev Calculates the underlying amount that can be supplied on the given market on AaveV3, reaching the supply cap.
    function _supplyGap(TestMarket storage market) internal view returns (uint256) {
        return market.supplyCap.zeroFloorSub(_totalSupplyToCap(market.underlying));
    }

    /// @dev Sets the supply cap of AaveV3 to the given input.
    function _setSupplyCap(TestMarket storage market, uint256 supplyCap) internal {
        market.supplyCap = supplyCap > 0 ? supplyCap * 10 ** market.decimals : type(uint256).max;

        poolAdmin.setSupplyCap(market.underlying, supplyCap);
    }

    /// @dev Calculates the underlying amount that can be borrowed on the given market on AaveV3, reaching the borrow cap.
    function _borrowGap(TestMarket storage market) internal view returns (uint256) {
        return market.borrowGap();
    }

    /// @dev Sets the borrow cap of AaveV3 to the given input.
    function _setBorrowCap(TestMarket storage market, uint256 borrowCap) internal {
        market.borrowCap = borrowCap > 0 ? borrowCap * 10 ** market.decimals : type(uint256).max;

        poolAdmin.setBorrowCap(market.underlying, borrowCap);
    }

    modifier bypassSupplyCap(address underlying, uint256 amount) {
        TestMarket storage market = testMarkets[underlying];

        uint256 supplyCapBefore = market.supplyCap;
        bool disableSupplyCap = amount < type(uint256).max - supplyCapBefore;
        if (disableSupplyCap) _setSupplyCap(market, 0);

        _;

        if (disableSupplyCap) _setSupplyCap(market, (supplyCapBefore + amount).divUp(10 ** market.decimals));
    }

    /// @dev Deposits the given amount of tokens on behalf of the given address, on AaveV3, increasing the supply cap if necessary.
    function _deposit(address underlying, uint256 amount, address onBehalf)
        internal
        bypassSupplyCap(underlying, amount)
    {
        _deal(underlying, address(this), amount);
        ERC20(underlying).safeApprove(address(pool), amount);
        pool.deposit(underlying, amount, onBehalf, 0);
    }

    /// @dev Bounds the input supply cap of AaveV3 so that it is exceeded after having deposited a given amount
    function _boundSupplyCapExceeded(TestMarket storage market, uint256 amount, uint256 supplyCap)
        internal
        view
        returns (uint256)
    {
        return bound(supplyCap, 1, (_totalSupplyToCap(market.underlying) + amount) / (10 ** market.decimals));
    }

    /// @dev Bounds the input borrow cap of AaveV3 so that it is exceeded after having deposited a given amount
    function _boundBorrowCapExceeded(TestMarket storage market, uint256 amount, uint256 borrowCap)
        internal
        view
        returns (uint256)
    {
        return bound(borrowCap, 1, (market.totalBorrow() + amount) / (10 ** market.decimals));
    }

    /// @dev Bounds the input between the minimum & the maximum USD amount expected in tests, without exceeding the market's supply cap.
    function _boundSupply(TestMarket storage market, uint256 amount) internal view returns (uint256) {
        return bound(amount, market.minAmount, Math.min(market.maxAmount, _supplyGap(market)));
    }

    /// @dev Bounds the input so that the amount returned can collateralize a debt between
    ///      the minimum & the maximum USD amount expected in tests, without exceeding the market's supply cap.
    function _boundCollateral(TestMarket storage collateralMarket, uint256 amount, TestMarket storage borrowedMarket)
        internal
        view
        returns (uint256)
    {
        return bound(
            amount,
            collateralMarket.minBorrowCollateral(borrowedMarket, borrowedMarket.minAmount, eModeCategoryId),
            Math.min(
                collateralMarket.minBorrowCollateral(
                    borrowedMarket,
                    Math.min(borrowedMarket.maxAmount, Math.min(borrowedMarket.liquidity(), borrowedMarket.borrowGap())),
                    eModeCategoryId
                ),
                _supplyGap(collateralMarket)
            )
        );
    }

    /// @dev Bounds the input between the minimum USD amount expected in tests
    ///      and the maximum borrowable quantity, without exceeding the market's liquidity nor its borrow cap.
    function _boundBorrow(TestMarket storage market, uint256 amount) internal view returns (uint256) {
        return bound(
            amount, market.minAmount, Math.min(market.maxAmount, Math.min(market.liquidity(), market.borrowGap()))
        );
    }

    /// @dev Bounds the fuzzing input to an arbitrary reasonable amount of iterations.
    function _boundMaxIterations(uint256 maxIterations) internal view returns (uint256) {
        return bound(maxIterations, 0, 32);
    }

    /// @dev Borrows from `user` on behalf of `onBehalf`, with collateral.
    function _borrowWithCollateral(
        address borrower,
        TestMarket storage collateralMarket,
        TestMarket storage borrowedMarket,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) internal returns (uint256 collateral, uint256 borrowed) {
        collateral = collateralMarket.minBorrowCollateral(borrowedMarket, amount, eModeCategoryId);
        _deal(collateralMarket.underlying, borrower, collateral);

        vm.startPrank(borrower);
        ERC20(collateralMarket.underlying).safeApprove(address(morpho), collateral);
        collateral = morpho.supplyCollateral(collateralMarket.underlying, collateral, borrower);
        borrowed = morpho.borrow(borrowedMarket.underlying, amount, onBehalf, receiver, maxIterations);
        vm.stopPrank();
    }

    /// @dev Borrows from `user` on behalf of `onBehalf`, without collateral.
    function _borrowWithoutCollateral(
        address borrower,
        TestMarket storage market,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) internal returns (uint256) {
        oracle.setAssetPrice(market.underlying, 0);

        return _borrowPriceZero(borrower, market, amount, onBehalf, receiver, maxIterations);
    }

    /// @dev Borrows a zero-priced asset from `user` on behalf of `onBehalf`.
    function _borrowPriceZero(
        address borrower,
        TestMarket storage market,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) internal returns (uint256 borrowed) {
        vm.prank(borrower);
        borrowed = morpho.borrow(market.underlying, amount, onBehalf, receiver, maxIterations);

        _deposit(
            testMarkets[dai].underlying,
            testMarkets[dai].minBorrowCollateral(market, borrowed, eModeCategoryId),
            address(morpho)
        ); // Make Morpho able to borrow again with some collateral. The DAI market is used here because some `market` can't be used as collateral such as USDT.

        oracle.setAssetPrice(market.underlying, market.price);
    }

    /// @dev Promotes the incoming (or already provided) supply, without collateral.
    function _promoteSupply(UserMock promoter, TestMarket storage market, uint256 amount) internal returns (uint256) {
        uint256 liquidity = market.liquidity();
        if (amount > liquidity) _deposit(market.underlying, amount - liquidity, address(0xdead));
        if (amount > market.borrowGap()) {
            _setBorrowCap(market, (market.totalBorrow() + amount).divUp(10 ** market.decimals));
        }

        oracle.setAssetPrice(market.underlying, 0);

        try promoter.borrow(market.underlying, amount) returns (uint256 borrowed) {
            amount = borrowed;

            _deposit(
                testMarkets[dai].underlying,
                testMarkets[dai].minBorrowCollateral(market, amount, eModeCategoryId),
                address(morpho)
            ); // Make Morpho able to borrow again with some collateral. The DAI market is used here because some `market` can't be used as collateral such as USDT.
        } catch {
            amount = 0;
        }

        oracle.setAssetPrice(market.underlying, market.price);

        return amount;
    }

    /// @dev Promotes the incoming (or already provided) borrow.
    function _promoteBorrow(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        bypassSupplyCap(market.underlying, amount)
        returns (uint256)
    {
        if (amount == 0) return 0;
        promoter.approve(market.underlying, amount);
        return promoter.supply(market.underlying, amount);
    }

    /// @dev Adds a given amount of idle supply on the given market.
    ///      Must not be called if some borrow is ready to be promoted peer-to-peer (otherwise `hacker` would only borrow-repay from the pool).
    function _increaseIdleSupply(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter, market, amount); // 100% peer-to-peer.

        address onBehalf = address(hacker);
        _borrowWithoutCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        // Set the supply cap as exceeded.
        _setSupplyCap(market, market.totalSupply() / (10 ** market.decimals));

        hacker.approve(market.underlying, amount);
        hacker.repay(market.underlying, amount, onBehalf);

        return amount;
    }

    /// @dev Adds a given amount of supply delta on the given market.
    ///      Must not be called if some borrow is ready to be promoted peer-to-peer (otherwise `hacker` would only borrow-repay from the pool).
    function _increaseSupplyDelta(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter, market, amount); // 100% peer-to-peer.

        address onBehalf = address(hacker);
        _borrowWithoutCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);

        Types.Iterations memory iterations = morpho.defaultIterations();

        // Set the max iterations to 0 upon repay to skip demotion and fallback to supply delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 0, withdraw: 10}));

        hacker.approve(market.underlying, amount);
        hacker.repay(market.underlying, amount, onBehalf);

        morpho.setDefaultIterations(iterations);

        return amount;
    }

    /// @dev Adds a given amount of borrow delta on the given market.
    ///      Must not be called if some supply is ready to be promoted peer-to-peer (otherwise `hacker` would only supply-withdraw from the pool).
    function _increaseBorrowDelta(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundSupply(market, amount);

        // Add liquidity to the pool to make sure there's enough to borrow (& promote the supply).
        _deposit(market.underlying, amount, address(0));

        amount = _promoteSupply(promoter, market, amount); // 100% peer-to-peer.

        hacker.approve(market.underlying, amount);
        hacker.supply(market.underlying, amount);

        Types.Iterations memory iterations = morpho.defaultIterations();

        // Set the max iterations to 0 upon withdraw to skip demotion and fallback to borrow delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 10, withdraw: 0}));

        hacker.withdraw(market.underlying, amount, 0);

        morpho.setDefaultIterations(iterations);

        return amount;
    }

    function _boundAddressValid(address input) internal view virtual returns (address) {
        input = _boundAddressNotZero(input);

        vm.assume(input != address(proxyAdmin)); // TransparentUpgradeableProxy: admin cannot fallback to proxy target.
        vm.assume(input != 0x807a96288A1A408dBC13DE2b1d087d10356395d2); // Proxy admin for USDC.

        return input;
    }

    function _boundOnBehalf(address onBehalf) internal view returns (address) {
        onBehalf = _boundAddressValid(onBehalf);

        return onBehalf;
    }

    function _boundReceiver(address input) internal view returns (address output) {
        output = _boundAddressValid(input);

        vm.assume(output != address(this));

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];

            vm.assume(output != market.underlying);
            vm.assume(output != market.aToken);
            vm.assume(output != market.variableDebtToken);
            vm.assume(output != market.stableDebtToken);
        }
    }

    function _prepareOnBehalf(address onBehalf) internal {
        if (onBehalf != address(user)) {
            vm.prank(onBehalf);
            morpho.approveManager(address(user), true);
        }
    }

    function _assertMarketUpdatedIndexes(Types.Market memory market, Types.Indexes256 memory futureIndexes) internal {
        assertEq(market.lastUpdateTimestamp, block.timestamp, "lastUpdateTimestamp != block.timestamp");
        assertEq(
            market.indexes.supply.poolIndex, futureIndexes.supply.poolIndex, "poolSupplyIndex != futurePoolSupplyIndex"
        );
        assertEq(
            market.indexes.borrow.poolIndex, futureIndexes.borrow.poolIndex, "poolBorrowIndex != futurePoolBorrowIndex"
        );
        assertEq(
            market.indexes.supply.p2pIndex, futureIndexes.supply.p2pIndex, "p2pSupplyIndex != futureP2PSupplyIndex"
        );
        assertEq(
            market.indexes.borrow.p2pIndex, futureIndexes.borrow.p2pIndex, "p2pBorrowIndex != futureP2PBorrowIndex"
        );
    }

    function _assertMarketAccountingZero(Types.Market memory market) internal {
        assertEq(market.deltas.supply.scaledDelta, 0, "scaledSupplyDelta != 0");
        assertEq(market.deltas.supply.scaledP2PTotal, 0, "scaledTotalSupplyP2P != 0");
        assertEq(market.deltas.borrow.scaledDelta, 0, "scaledBorrowDelta != 0");
        assertEq(market.deltas.borrow.scaledP2PTotal, 0, "scaledTotalBorrowP2P != 0");
        assertEq(market.idleSupply, 0, "idleSupply != 0");
    }
}
