// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {IPositionsManager} from "src/interfaces/IPositionsManager.sol";

import {TestMarket, TestMarketLib} from "test/helpers/TestMarketLib.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {Morpho} from "src/Morpho.sol";
import {PositionsManager} from "src/PositionsManager.sol";
import {UserMock} from "test/mocks/UserMock.sol";
import "./ForkTest.sol";

contract IntegrationTest is ForkTest {
    using stdStorage for StdStorage;
    using Math for uint256;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using TestMarketLib for TestMarket;

    uint8 internal constant E_MODE_CATEGORY_ID = 0;
    uint256 internal constant INITIAL_BALANCE = 10_000_000_000 ether;

    // AaveV3 base currency is USD, 8 decimals on all L2s.
    uint256 internal constant MIN_USD_AMOUNT = 0.01e8; // 0.01$
    uint256 internal constant MAX_USD_AMOUNT = 500_000_000e8; // 500m$

    IMorpho internal morpho;
    IPositionsManager internal positionsManager;

    ProxyAdmin internal proxyAdmin;

    IMorpho internal morphoImpl;
    TransparentUpgradeableProxy internal morphoProxy;

    UserMock internal user;
    UserMock internal promoter1;
    UserMock internal promoter2;
    UserMock internal hacker;

    mapping(address => TestMarket) internal testMarkets;

    address[] internal underlyings;
    address[] internal collateralUnderlyings;
    address[] internal borrowableUnderlyings;

    function setUp() public virtual override {
        _deploy();

        for (uint256 i; i < allUnderlyings.length; ++i) {
            _createMarket(allUnderlyings[i], 0, 33_33);
        }

        // Supply dust to make UserConfigurationMap.isUsingAsCollateralOne() always return true.
        _deposit(testMarkets[weth], 1e12, address(morpho));
        _deposit(testMarkets[dai], 1e12, address(morpho));

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

    function _deploy() internal {
        positionsManager = new PositionsManager(address(addressesProvider), E_MODE_CATEGORY_ID);
        morphoImpl = new Morpho(address(addressesProvider), E_MODE_CATEGORY_ID);

        proxyAdmin = new ProxyAdmin();
        morphoProxy = new TransparentUpgradeableProxy(payable(address(morphoImpl)), address(proxyAdmin), "");
        morpho = Morpho(payable(address(morphoProxy)));

        morpho.initialize(address(positionsManager), Types.Iterations({repay: 10, withdraw: 10}));
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
        returns (TestMarket storage market, DataTypes.ReserveData memory reserve)
    {
        reserve = pool.getReserveData(underlying);

        market = testMarkets[underlying];
        market.aToken = reserve.aTokenAddress;
        market.variableDebtToken = reserve.variableDebtTokenAddress;
        market.stableDebtToken = reserve.stableDebtTokenAddress;
        market.underlying = underlying;
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

        market.isBorrowable = reserve.configuration.getBorrowingEnabled() && !reserve.configuration.getSiloedBorrowing()
            && !reserve.configuration.getBorrowableInIsolation()
            && (E_MODE_CATEGORY_ID == 0 || E_MODE_CATEGORY_ID == reserve.configuration.getEModeCategory());

        vm.label(reserve.aTokenAddress, string.concat("a", market.symbol));
        vm.label(reserve.variableDebtTokenAddress, string.concat("vd", market.symbol));
        vm.label(reserve.stableDebtTokenAddress, string.concat("sd", market.symbol));
    }

    function _createMarket(address underlying, uint16 reserveFactor, uint16 p2pIndexCursor) internal {
        (TestMarket storage market,) = _initMarket(underlying, reserveFactor, p2pIndexCursor);

        underlyings.push(underlying);
        if (market.ltv > 0) collateralUnderlyings.push(underlying);
        if (market.isBorrowable) borrowableUnderlyings.push(underlying);

        morpho.createMarket(market.underlying, market.reserveFactor, market.p2pIndexCursor);
    }

    /// @dev Calculates the underlying amount that can be supplied on the given market on AaveV3, reaching the supply cap.
    function _supplyGap(TestMarket storage market) internal view returns (uint256) {
        return market.supplyCap.zeroFloorSub(market.totalSupply() + _accruedToTreasury(market.underlying));
    }

    /// @dev Sets the supply cap of AaveV3 to the given input.
    function _setSupplyCap(TestMarket storage market, uint256 supplyCap) internal {
        market.supplyCap = supplyCap > 0 ? supplyCap * 10 ** market.decimals : type(uint256).max;

        poolAdmin.setSupplyCap(market.underlying, supplyCap);
    }

    /// @dev Sets the borrow cap of AaveV3 to the given input.
    function _setBorrowCap(TestMarket storage market, uint256 borrowCap) internal {
        market.borrowCap = borrowCap > 0 ? borrowCap * 10 ** market.decimals : type(uint256).max;

        poolAdmin.setBorrowCap(market.underlying, borrowCap);
    }

    modifier bypassSupplyCap(TestMarket storage market, uint256 amount) {
        uint256 supplyCapBefore = market.supplyCap;
        bool disableSupplyCap = amount <= type(uint256).max - supplyCapBefore;
        if (disableSupplyCap) _setSupplyCap(market, 0);

        _;

        if (disableSupplyCap) _setSupplyCap(market, (supplyCapBefore + amount).divUp(10 ** market.decimals));
    }

    /// @dev Deposits the given amount of tokens on behalf of the given address, on AaveV3, increasing the supply cap if necessary.
    function _deposit(TestMarket storage market, uint256 amount, address onBehalf)
        internal
        bypassSupplyCap(market, amount)
    {
        deal(market.underlying, address(this), amount);
        ERC20(market.underlying).approve(address(pool), amount);
        pool.deposit(market.underlying, amount, onBehalf, 0);
    }

    /// @dev Bounds the input supply cap of AaveV3 so that it is exceeded after having deposited a given amount
    function _boundSupplyCapExceeded(TestMarket storage market, uint256 amount, uint256 supplyCap)
        internal
        view
        returns (uint256)
    {
        return bound(
            supplyCap,
            1,
            (market.totalSupply() + _accruedToTreasury(market.underlying) + amount) / (10 ** market.decimals)
        );
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
            collateralMarket.minBorrowCollateral(borrowedMarket, borrowedMarket.minAmount),
            Math.min(
                collateralMarket.minBorrowCollateral(borrowedMarket, borrowedMarket.maxAmount),
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

    /// @dev Borrows from `user` on behalf of `onBehalf`, without collateral.
    function _borrowNoCollateral(
        address borrower,
        TestMarket storage market,
        uint256 amount,
        address onBehalf,
        address receiver,
        uint256 maxIterations
    ) internal returns (uint256 borrowed) {
        oracle.setAssetPrice(market.underlying, 0);

        vm.prank(borrower);
        borrowed = morpho.borrow(market.underlying, amount, onBehalf, receiver, maxIterations);

        _deposit(market, market.minBorrowCollateral(market, borrowed), address(morpho)); // Make Morpho able to borrow again with some collateral.

        oracle.setAssetPrice(market.underlying, market.price);
    }

    /// @dev Promotes the incoming (or already provided) supply, without collateral.
    function _promoteSupply(UserMock promoter, TestMarket storage market, uint256 amount) internal returns (uint256) {
        uint256 liquidity = market.liquidity();
        if (amount > liquidity) _deposit(market, amount - liquidity, address(0xdead));
        if (amount > market.borrowGap()) {
            _setBorrowCap(market, (market.totalBorrow() + amount).divUp(10 ** market.decimals));
        }

        oracle.setAssetPrice(market.underlying, 0);

        try promoter.borrow(market.underlying, amount) returns (uint256 borrowed) {
            amount = borrowed;

            market.resetPreviousIndex(address(morpho)); // Enable borrow/repay in same block.
            _deposit(market, market.minBorrowCollateral(market, amount), address(morpho)); // Make Morpho able to borrow again with some collateral.
        } catch {
            amount = 0;
        }

        oracle.setAssetPrice(market.underlying, market.price);

        return amount;
    }

    /// @dev Promotes the incoming (or already provided) borrow.
    function _promoteBorrow(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        bypassSupplyCap(market, amount)
        returns (uint256)
    {
        promoter.approve(market.underlying, amount);
        return promoter.supply(market.underlying, amount);
    }

    /// @dev Adds a given amount of idle supply on the given market.
    function _increaseIdleSupply(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter, market, amount); // 100% peer-to-peer.

        address onBehalf = address(hacker);
        _borrowNoCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);
        market.resetPreviousIndex(address(morpho)); // Enable borrow/repay in same block.

        // Set the supply cap as exceeded.
        _setSupplyCap(market, market.totalSupply() / (10 ** market.decimals));

        hacker.approve(market.underlying, amount);
        hacker.repay(market.underlying, amount, onBehalf);

        return amount;
    }

    /// @dev Adds a given amount of supply delta on the given market.
    function _increaseSupplyDelta(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundBorrow(market, amount);
        amount = _promoteBorrow(promoter, market, amount); // 100% peer-to-peer.

        address onBehalf = address(hacker);
        _borrowNoCollateral(onBehalf, market, amount, onBehalf, onBehalf, DEFAULT_MAX_ITERATIONS);
        market.resetPreviousIndex(address(morpho)); // Enable borrow/repay in same block.

        Types.Iterations memory iterations = morpho.defaultIterations();

        // Set the max iterations to 0 upon repay to skip demotion and fallback to supply delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 0, withdraw: 10}));

        hacker.approve(market.underlying, amount);
        hacker.repay(market.underlying, amount, onBehalf);

        morpho.setDefaultIterations(iterations);

        return amount;
    }

    /// @dev Adds a given amount of borrow delta on the given market.
    function _increaseBorrowDelta(UserMock promoter, TestMarket storage market, uint256 amount)
        internal
        returns (uint256)
    {
        amount = _boundSupply(market, amount);
        amount = _promoteSupply(promoter, market, amount); // 100% peer-to-peer.

        hacker.approve(market.underlying, amount);
        hacker.supply(market.underlying, amount);

        Types.Iterations memory iterations = morpho.defaultIterations();

        // Set the max iterations to 0 upon withdraw to skip demotion and fallback to borrow delta.
        morpho.setDefaultIterations(Types.Iterations({repay: 10, withdraw: 0}));

        hacker.withdraw(market.underlying, amount);
        market.resetPreviousIndex(address(morpho)); // Enable borrow/repay in same block.

        morpho.setDefaultIterations(iterations);

        return amount;
    }
}
