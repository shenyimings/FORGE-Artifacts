// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/utils/UUPSProxy.sol";
import "../../../contracts/SwapGateway.sol";
import "../../../contracts/MultiLogic.sol";
import "../../../contracts/StorageV3.sol";
import "../../../contracts/strategies/lbf/venus/VenusLogic.sol";
import "../../../contracts/strategies/lbf/venus/VenusStatistics.sol";
import "../../../contracts/strategies/lbl/LendBorrowLendStrategy.sol";
import "../../../contracts/interfaces/IXToken.sol";
import "../../../contracts/interfaces/IStrategyStatistics.sol";
import "../../../contracts/interfaces/IStorage.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

struct singleStrategy {
    address logicContract;
    address strategyContract;
}

interface IMultiLogic {
    function initStrategies(
        string[] calldata _strategyName,
        singleStrategy[] calldata _multiStrategy
    ) external;

    function setPercentages(address _token, uint256[] calldata _percentages)
        external;
}

interface IStorageTest {
    function setBLID(address) external;

    function deposit(uint256 amount, address token) external payable;

    function withdraw(uint256 amount, address token) external;

    function addToken(address _token, address _oracles) external;

    function setMultiLogicProxy(address) external;

    function setOracleDeviationLimit(uint256) external;
}

contract VenusLblStrategyBNBTest is Test {
    uint256 private mainnetFork;

    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    VenusStatistics public statistics;
    SwapGateway public swapGateway;

    VenusLogic strategyLogic;
    LendBorrowLendStrategy strategy;
    SwapInfo swapInfo;

    uint256 private constant BLOCK_NUMBER = 29857834;
    address private constant ZERO_ADDRESS = address(0);
    address expense = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    address comptroller = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    address rainMaker = 0xfD36E2c2a6789Db23113685031d7F16329158384;
    address blid = 0x766AFcf83Fd5eaf884B3d529b432CA27A6d84617;
    address pancakeSwapRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address multiLogicProxy;
    address _storage;
    address logic;

    address vETH = 0xf508fCD89b8bd15579dc79A6827cB4686A3592c8;
    address vWBETH = 0x6CFdEc747f37DAf3b87a35a1D9c8AD3063A1A8A0;
    address BNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address WBETH = 0xa2E3356610840701BDf5611a53974510Ae27E2e1;
    address ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address XVS = 0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63;

    uint256 _borrowRateMin = 600000000000000000;
    uint256 _borrowRateMax = 800000000000000000;
    uint8 _circlesCount = 10;
    address rewardsToken = XVS;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("bsc"), BLOCK_NUMBER);

        vm.startPrank(owner);

        // Storage
        _initializeProxy();

        // MultiLogic
        MultiLogic multiLogic = new MultiLogic();
        multiLogic.__MultiLogicProxy_init();
        multiLogic.setStorage(_storage);
        multiLogicProxy = address(multiLogic);

        // SwapGateway
        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(pancakeSwapRouter, 2);

        swapGateway.setWETH(BNB);

        // Statistics
        statistics = new VenusStatistics();
        statistics.__StrategyStatistics_init();
        statistics.setSwapGateway(address(swapGateway));

        statistics.setBLID(blid);

        address[] memory path = new address[](2);
        path[0] = blid;
        path[1] = USDT;
        statistics.setBLIDSwap(pancakeSwapRouter, path);

        statistics.setPriceOracle(
            USDT,
            0xB97Ad0E74fa7d920791E90258A6E2085088b4320
        ); // USDT

        statistics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        ); // BNB

        statistics.setPriceOracle(
            BUSD,
            0xcBb98864Ef56E9042e7d2efef76141f15731B82f
        ); // BUSD

        statistics.setPriceOracle(
            ETH,
            0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e
        ); // ETH

        // strategyLogic
        strategyLogic = new VenusLogic();
        strategyLogic.__LendingLogic_init(comptroller, rainMaker);
        logic = address(strategyLogic);

        strategyLogic.setExpenseAddress(expense);
        strategyLogic.setMultiLogicProxy(multiLogicProxy);
        strategyLogic.setBLID(blid);
        strategyLogic.setSwapGateway(address(swapGateway));

        strategyLogic.approveTokenForSwap(address(swapGateway), blid);
        strategyLogic.approveTokenForSwap(address(swapGateway), rewardsToken);

        // strategy
        strategy = new LendBorrowLendStrategy();
        strategy.__Strategy_init(comptroller, logic);

        strategy.setBLID(blid);
        strategy.setMultiLogicProxy(multiLogicProxy);
        strategy.setStrategyStatistics(address(statistics));
        strategy.setCirclesCount(_circlesCount);
        strategy.setAvoidLiquidationFactor(5);

        strategy.setMinStorageAvailable(3 * 10**18);
        strategy.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy.setMinBLIDPerRewardsToken(0);
        strategyLogic.setAdmin(address(strategy));
        strategy.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day

        // MultiLogicProxy Init
        MultiLogic.singleStrategy memory strategyInfoOla;
        strategyInfoOla.logicContract = logic;
        strategyInfoOla.strategyContract = address(strategy);

        string[] memory _strategyName = new string[](1);
        _strategyName[0] = "VenusLbl";
        MultiLogic.singleStrategy[]
            memory _multiStrategy = new MultiLogic.singleStrategy[](1);
        _multiStrategy[0] = strategyInfoOla;

        multiLogic.initStrategies(_strategyName, _multiStrategy);
        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 10000;
        multiLogic.setPercentages(USDT, percentages);
        multiLogic.setPercentages(ZERO_ADDRESS, percentages);

        // Storage init
        IStorageTest(_storage).setBLID(blid);
        IStorageTest(_storage).setMultiLogicProxy(address(multiLogic));
        IStorageTest(_storage).addToken(
            ETH,
            0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e
        );
        IStorageTest(_storage).setOracleDeviationLimit(1 ether);

        // Deal and swap ETH
        vm.deal(owner, 10**21);

        path = new address[](2);
        path[0] = ZERO_ADDRESS;
        path[1] = ETH;

        swapGateway.swap{value: 10**21}(
            pancakeSwapRouter,
            10**21,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        // Deal and swap ETH
        IStorageTest(_storage).addToken(
            WBETH,
            0x9ef1B8c0E4F7dc8bF5719Ea496883DC6401d5b2e
        );

        vm.deal(owner, 10**21);

        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = ETH;
        path[2] = WBETH;

        swapGateway.swap{value: 10**21}(
            pancakeSwapRouter,
            10**21,
            0,
            path,
            true,
            block.timestamp + 3600
        );
        vm.stopPrank();
    }

    function xtest_ETH_WBETH() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(vWBETH);
        strategy.setSupplyXToken(vETH);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = pancakeSwapRouter;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](5);
        swapInfo.paths[0][0] = XVS;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        swapInfo.paths[0][2] = BUSD;
        swapInfo.paths[0][3] = USDT;
        swapInfo.paths[0][4] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = pancakeSwapRouter;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = XVS;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        swapInfo.paths[0][2] = ETH;
        swapInfo.paths[0][3] = WBETH;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = pancakeSwapRouter;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](6);
        swapInfo.paths[0][0] = WBETH;
        swapInfo.paths[0][1] = ETH;
        swapInfo.paths[0][2] = ZERO_ADDRESS;
        swapInfo.paths[0][3] = BUSD;
        swapInfo.paths[0][4] = USDT;
        swapInfo.paths[0][5] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = pancakeSwapRouter;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = WBETH;
        swapInfo.paths[0][1] = ETH;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = pancakeSwapRouter;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](5);
        swapInfo.paths[0][0] = ETH;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        swapInfo.paths[0][2] = BUSD;
        swapInfo.paths[0][3] = USDT;
        swapInfo.paths[0][4] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(vETH, ETH, vWBETH, WBETH, 10**18);

        vm.stopPrank();
    }

    function xtest_WBETH_WBETH() public {
        vm.startPrank(owner);
        console.log(IERC20MetadataUpgradeable(WBETH).balanceOf(owner));
        // Configuration
        strategy.setStrategyXToken(vWBETH);
        strategy.setSupplyXToken(vWBETH);

        _testStrategy(vWBETH, WBETH, vWBETH, WBETH, 10**18);

        vm.stopPrank();
    }

    function _testStrategy(
        address supplyXToken,
        address supplyToken,
        address strategyXToken,
        address strategyToken,
        uint256 depositAmount
    ) private {
        uint256 blidExpense;
        uint256 blidStorage;
        uint256 blidExpenseNew;
        uint256 blidStorageNew;
        uint256 Rewards_balance;

        XTokenInfo memory tokenInfo;

        // Deposit to storage
        if (supplyToken == ZERO_ADDRESS) {
            vm.deal(owner, depositAmount);
            IStorageTest(_storage).deposit{value: depositAmount}(
                depositAmount,
                supplyToken
            );
        } else {
            IERC20MetadataUpgradeable(supplyToken).approve(
                _storage,
                depositAmount * 100
            );
            IStorageTest(_storage).deposit(depositAmount, supplyToken);
        }

        console.log(
            "Available in Storage : ",
            IMultiLogicProxy(multiLogicProxy).getTokenAvailable(
                supplyToken,
                logic
            )
        );

        // Test useToken
        console.log("============= Use Token =============");
        strategy.setMinStorageAvailable(depositAmount * 10);
        assertEq(strategy.checkUseToken(), false);
        assertEq(strategy.checkRebalance(), false);
        strategy.useToken();
        tokenInfo = statistics.getStrategyXTokenInfo(supplyXToken, logic);
        assertEq(tokenInfo.totalSupply, 0);

        strategy.setMinStorageAvailable(depositAmount / 10);
        assertEq(strategy.checkUseToken(), true);
        strategy.useToken();
        console.log(
            "Available in Storage : ",
            IMultiLogicProxy(multiLogicProxy).getTokenAvailable(
                supplyToken,
                logic
            )
        );
        tokenInfo = statistics.getStrategyXTokenInfo(supplyXToken, logic);
        assertEq(tokenInfo.totalSupply > 0, true);
        _showXTokenInfo();

        // Test Create Circle
        console.log("============= Create Circle =============");
        assertEq(strategy.checkRebalance(), true);
        strategy.rebalance();
        tokenInfo = _showXTokenInfo();
        assertEq(tokenInfo.borrowAmount > 0, true);
        assertEq(strategy.checkRebalance(), false);

        if (strategyToken != ZERO_ADDRESS) {
            // Test Claim
            console.log("============= Claim =============");
            vm.warp(block.timestamp + 3000000);
            vm.roll(block.number + 999999);

            blidExpense = IERC20MetadataUpgradeable(blid).balanceOf(expense);
            blidStorage = IERC20MetadataUpgradeable(blid).balanceOf(_storage);

            console.log("BLID of expense   : ", blidExpense);
            console.log("BLID of storage   : ", blidStorage);

            console.log("-- After Claim with small DF amount --");
            strategy.setMinRewardsSwapLimit(10**25);

            address[] memory xTokens = new address[](1);
            xTokens[0] = strategyXToken;
            IDistributionVenus(comptroller).claimVenus(logic, xTokens);

            return;
            strategy.claimRewards();
            blidExpenseNew = IERC20MetadataUpgradeable(blid).balanceOf(expense);
            blidStorageNew = IERC20MetadataUpgradeable(blid).balanceOf(
                _storage
            );
            Rewards_balance = IERC20MetadataUpgradeable(rewardsToken).balanceOf(
                    logic
                );

            console.log("BLID of expense   : ", blidExpenseNew);
            console.log("BLID of storage   : ", blidStorageNew);
            console.log("Rewards of Logic  : ", Rewards_balance);

            assertEq(blidExpenseNew >= blidExpense, true);
            assertEq(blidStorageNew >= blidStorage, true);
            assertEq(Rewards_balance > 0, true);

            console.log("-- After Claim with enough DF amount --");
            vm.warp(block.timestamp + 20);
            blidExpense = blidExpenseNew;
            blidStorage = blidStorageNew;

            strategy.setMinRewardsSwapLimit(1000000);
            strategy.claimRewards();

            blidExpenseNew = IERC20MetadataUpgradeable(blid).balanceOf(expense);
            blidStorageNew = IERC20MetadataUpgradeable(blid).balanceOf(
                _storage
            );
            Rewards_balance = IERC20MetadataUpgradeable(rewardsToken).balanceOf(
                    logic
                );

            console.log("BLID of expense   : ", blidExpenseNew);
            console.log("BLID of storage   : ", blidStorageNew);
            console.log("Rewards of Logic  : ", Rewards_balance);

            assertEq(blidExpenseNew > blidExpense, true);
            assertEq(blidStorageNew > blidStorage, true);
            assertEq(Rewards_balance == 0, true);

            console.log("-- Rewards Price Kill Switch Active --");
            strategy.setRewardsTokenPrice(
                (statistics.getRewardsTokenPrice(comptroller, rewardsToken) *
                    8638) / 8640
            );
            vm.warp(block.timestamp + 2000);
            vm.roll(block.number + 99999);
            strategy.claimRewards();
            Rewards_balance = IERC20MetadataUpgradeable(rewardsToken).balanceOf(
                    logic
                );
            console.log("Rewards of Logic  : ", Rewards_balance);
            assertEq(Rewards_balance > 0, true);

            console.log("-- Rewards Price Kill Switch Deactive --");
            strategy.setRewardsTokenPrice(
                (statistics.getRewardsTokenPrice(comptroller, rewardsToken) *
                    8639) / 8640
            );
            vm.warp(block.timestamp + 2000);
            vm.roll(block.number + 99999);
            strategy.claimRewards();
            Rewards_balance = IERC20MetadataUpgradeable(rewardsToken).balanceOf(
                    logic
                );
            console.log("Rewards of Logic  : ", Rewards_balance);
            assertEq(Rewards_balance, 0);
            tokenInfo = _showXTokenInfo();

            if (supplyXToken == strategyXToken) {
                assertEq(
                    int256(tokenInfo.lendingAmount) -
                        int256(tokenInfo.totalSupply) +
                        int256(tokenInfo.borrowAmount) <=
                        1,
                    true
                );
            } else {
                XTokenInfo memory supplyTokenInfo = statistics
                    .getStrategyXTokenInfo(supplyXToken, logic);
                assertEq(
                    int256(supplyTokenInfo.lendingAmountUSD) -
                        int256(supplyTokenInfo.totalSupplyUSD) -
                        int256(tokenInfo.totalSupplyUSD) +
                        int256(tokenInfo.borrowAmountUSD) <=
                        (
                            IERC20MetadataUpgradeable(strategyToken)
                                .decimals() == 18
                                ? int256(1000)
                                : int256(
                                    2 *
                                        10 **
                                            (18 -
                                                IERC20MetadataUpgradeable(
                                                    strategyToken
                                                ).decimals())
                                )
                        ),
                    true
                );
            }
        }

        // Test destroy
        console.log("============= Rebalance - Destroy Circle =============");
        assertEq(strategy.checkRebalance(), false);
        strategy.setRebalanceParameter(500000000000000000, 600000000000000000);
        assertEq(strategy.checkRebalance(), true);
        strategy.rebalance();
        assertEq(strategy.checkRebalance(), false);
        tokenInfo = _showXTokenInfo();

        // Test withdraw
        console.log("============= Withdraw =============");
        IStorageTest(_storage).withdraw(depositAmount / 2, supplyToken);
        assertEq(strategy.checkRebalance(), false);
        tokenInfo = _showXTokenInfo();

        // Test rebalance
        console.log("============= Rebalance - Create Circle =============");
        strategy.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        assertEq(strategy.checkRebalance(), true);
        strategy.rebalance();
        assertEq(strategy.checkRebalance(), false);
        tokenInfo = _showXTokenInfo();

        // Test destroy All
        console.log("============= Destroy All =============");
        vm.roll(block.number + 1000000);
        vm.warp(block.timestamp + 100);

        blidExpense = IERC20MetadataUpgradeable(blid).balanceOf(expense);
        blidStorage = IERC20MetadataUpgradeable(blid).balanceOf(_storage);

        strategy.destroyAll();

        blidExpenseNew = IERC20MetadataUpgradeable(blid).balanceOf(expense);
        blidStorageNew = IERC20MetadataUpgradeable(blid).balanceOf(_storage);
        Rewards_balance = IERC20MetadataUpgradeable(rewardsToken).balanceOf(
            logic
        );

        console.log(
            "Available in Storage : ",
            IMultiLogicProxy(multiLogicProxy).getTokenAvailable(
                supplyToken,
                logic
            )
        );
        tokenInfo = _showXTokenInfo();
        assertEq(strategy.checkRebalance(), false);
        assertEq(strategy.checkUseToken(), true);
        assertEq(tokenInfo.borrowAmount, 0);
        assertEq(tokenInfo.totalSupply, 0);

        if (strategyToken != ZERO_ADDRESS) {
            console.log("BLID of expense   : ", blidExpense);
            console.log("BLID of storage   : ", blidStorage);
            console.log("BLID of expense   : ", blidExpenseNew);
            console.log("BLID of storage   : ", blidStorageNew);
            console.log("Rewards of Logic  : ", Rewards_balance);

            if (supplyXToken == strategyXToken) {
                assertEq(
                    int256(tokenInfo.lendingAmount) -
                        int256(tokenInfo.totalSupply) +
                        int256(tokenInfo.borrowAmount),
                    0
                );
            } else {
                XTokenInfo memory supplyTokenInfo = statistics
                    .getStrategyXTokenInfo(supplyXToken, logic);
                assertEq(
                    int256(supplyTokenInfo.lendingAmountUSD) -
                        int256(supplyTokenInfo.totalSupplyUSD) -
                        int256(tokenInfo.totalSupplyUSD) +
                        int256(tokenInfo.borrowAmountUSD) <
                        1, // USDC deciaml = 6
                    true
                );
            }

            assertEq(blidExpenseNew > blidExpense, true);
            assertEq(blidStorageNew > blidStorage, true);

            // Withdraw All
            IStorageTest(_storage).withdraw(depositAmount / 2, supplyToken);
        }

        // Deposit / Withdraw All
        if (strategyToken != ZERO_ADDRESS) {
            console.log("============= Deposit/Withdraw All =============");
            if (supplyToken == ZERO_ADDRESS) {
                IStorageTest(_storage).deposit{value: depositAmount}(
                    depositAmount,
                    supplyToken
                );
            } else {
                IStorageTest(_storage).deposit(depositAmount, supplyToken);
            }

            strategy.setMinStorageAvailable(depositAmount / 10);

            strategy.useToken();
            strategy.rebalance();

            vm.roll(block.number + 1000000);
            vm.warp(block.timestamp + 100);
            IStorageTest(_storage).withdraw(depositAmount, supplyToken);

            tokenInfo = _showXTokenInfo();
            assertEq(tokenInfo.lendingAmount, 0);
        }
    }

    function _showXTokenInfo()
        private
        view
        returns (XTokenInfo memory xTokenInfo)
    {
        address supplyXToken = strategy.supplyXToken();
        address strategyXToken = strategy.strategyXToken();

        xTokenInfo = statistics.getStrategyXTokenInfo(strategyXToken, logic);
        XTokenInfo memory supplyXTokenInfo = statistics.getStrategyXTokenInfo(
            supplyXToken,
            logic
        );

        console.log("lendingAmount     : ", supplyXTokenInfo.lendingAmount);
        if (supplyXToken != strategyXToken) {
            console.log("supplyAmount      : ", supplyXTokenInfo.totalSupply);
        }
        console.log("totalSupply       : ", xTokenInfo.totalSupply);
        console.log("borrowAmount      : ", xTokenInfo.borrowAmount);
        console.log("borrowLimit       : ", xTokenInfo.borrowLimit);

        int256 diff;
        if (supplyXToken == strategyXToken) {
            diff =
                int256(xTokenInfo.lendingAmount) -
                int256(xTokenInfo.totalSupply) +
                int256(xTokenInfo.borrowAmount);
        } else {
            diff =
                int256(supplyXTokenInfo.lendingAmountUSD) -
                int256(supplyXTokenInfo.totalSupplyUSD) -
                int256(xTokenInfo.totalSupplyUSD) +
                int256(xTokenInfo.borrowAmountUSD);
        }
        if (diff > 0) console.log("supply required   : ", uint256(diff));
        if (diff < 0) console.log("redeem required   : ", uint256(0 - diff));

        console.log("underlyingBalance : ", xTokenInfo.underlyingBalance);
        if (supplyXToken != strategyXToken) {
            console.log("--- USD ---");
            console.log(
                "lendingAmount     : ",
                supplyXTokenInfo.lendingAmountUSD
            );
            console.log(
                "supplyAmount      : ",
                supplyXTokenInfo.totalSupplyUSD
            );
            console.log("totalSupply       : ", xTokenInfo.totalSupplyUSD);
            console.log("borrowAmount      : ", xTokenInfo.borrowAmountUSD);
            console.log(
                "borrowLimit       : ",
                supplyXTokenInfo.borrowLimitUSD + xTokenInfo.borrowLimitUSD
            );
        }

        uint256 borrowRate = 0;
        if (supplyXToken == strategyXToken) {
            borrowRate = xTokenInfo.borrowLimit == 0
                ? 0
                : ((xTokenInfo.borrowAmount * 100) / xTokenInfo.borrowLimit);
        } else {
            borrowRate = (xTokenInfo.borrowLimitUSD +
                supplyXTokenInfo.borrowLimitUSD ==
                0)
                ? 0
                : (xTokenInfo.borrowAmountUSD * 100) /
                    (xTokenInfo.borrowLimitUSD +
                        supplyXTokenInfo.borrowLimitUSD);
        }
        console.log("borrow Rate       : ", borrowRate);
    }

    function _initializeProxy() private {
        /* Use UUPXProxy pattern for oppenzeppelin initializer
         * - in UpgradeableBse _initialize has "initializer" modifier
         * - in DForceLogic __Logic_init doesn't have "initializer" modifer
         * - import "../../../contracts/utils/UUPSProxy.sol";
         */

        UUPSProxy storageProxy;
        StorageV3 storageImple;
        StorageV3 storageContract;
        storageImple = new StorageV3();
        storageProxy = new UUPSProxy(address(storageImple), "");
        storageContract = StorageV3(payable(address(storageProxy)));
        storageContract.initialize();

        _storage = address(storageContract);
    }
}
