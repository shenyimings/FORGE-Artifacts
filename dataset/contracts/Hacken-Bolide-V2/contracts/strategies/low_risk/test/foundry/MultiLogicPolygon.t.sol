// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../contracts/utils/UUPSProxy.sol";
import "../../contracts/SwapGateway.sol";
import "../../contracts/MultiLogic.sol";
import "../../contracts/StorageV3.sol";
import "../../contracts/strategies/lbl/dforce/DForceStatistics.sol";
import "../../contracts/strategies/lbl/dforce/DForceLogic.sol";
import "../../contracts/strategies/lbl/LendBorrowLendStrategy.sol";
import "../../contracts/interfaces/IXToken.sol";
import "../../contracts/interfaces/IStrategyStatistics.sol";
import "../../contracts/interfaces/IStorage.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

struct singleStrategy {
    address logicContract;
    address strategyContract;
}

interface IStorageTest {
    function deposit(uint256 amount, address token) external payable;

    function withdraw(uint256 amount, address token) external;

    function addToken(address _token, address _oracles) external;

    function setMultiLogicProxy(address) external;

    function setBLID(address) external;

    function setOracleDeviationLimit(uint256) external;
}

contract MultiLogicPolygonTest is Test {
    uint256 private mainnetFork;

    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    DForceStatistics public statistics;
    SwapGateway public swapGateway;
    MultiLogic public multiLogic;

    DForceLogic strategyLogic1;
    LendBorrowLendStrategy strategy1;
    DForceLogic strategyLogic2;
    LendBorrowLendStrategy strategy2;
    DForceLogic strategyLogic3;
    LendBorrowLendStrategy strategy3;

    SwapInfo swapInfo;

    uint256 private constant BLOCK_NUMBER = 42_060_987; //41_177_576;
    address private constant ZERO_ADDRESS = address(0);
    address expense = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    address comptroller = 0x52eaCd19E38D501D006D2023C813d7E37F025f37;
    address rainMaker = 0x47C19A2ab52DA26551A22e2b2aEED5d19eF4022F;
    address blid = 0x4b27Cd6E6a5E83d236eAD376D256Fe2F9e9f0d2E;
    address sushiswapRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
    address uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address quickswapV3Router = 0xf5b509bB0909a69B1c207E495f687a596C168E12;
    address multiLogicProxy = 0xF248b900B2ba6942FF189F986c2a5baeD251Ff68;
    address _storage = 0x102103ca65D53387A9B4186B15D9bb75D0b135cC;
    address logic1;
    address logic2;
    address logic3;

    address iUSDT = 0xb3ab7148cCCAf66686AD6C1bE24D83e58E6a504e;
    address iUSDC = 0x5268b3c4afb0860D365a093C184985FCFcb65234;
    address iDAI = 0xec85F77104Ffa35a5411750d70eDFf8f1496d95b;
    address iMATIC = 0x6A3fE5342a4Bd09efcd44AC5B9387475A0678c74;
    address MATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address DF = 0x08C15FA26E519A78a666D19CE5C646D55047e0a3;

    uint256 _borrowRateMin = 600000000000000000;
    uint256 _borrowRateMax = 800000000000000000;
    uint8 _circlesCount = 10;
    address rewardsToken = DF;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("polygon"), BLOCK_NUMBER);
        vm.startPrank(owner);

        // Storage
        _initializeProxy();

        // MultiLogic
        multiLogic = new MultiLogic();
        multiLogic.__MultiLogicProxy_init();
        multiLogic.setStorage(_storage);
        multiLogicProxy = address(multiLogic);

        // SwapGateway
        swapGateway = new SwapGateway();
        swapGateway.__SwapGateway_init();
        swapGateway.addSwapRouter(sushiswapRouter, 2);
        swapGateway.addSwapRouter(uniswapV3Router, 3);
        swapGateway.addSwapRouter(quickswapV3Router, 5);

        swapGateway.setWETH(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

        // Statistics
        statistics = new DForceStatistics();
        statistics.__StrategyStatistics_init();
        statistics.setSwapGateway(address(swapGateway));
        statistics.setRewardsXToken(0xcB5D9b6A9BA8eA6FA82660fAA9cC130586F939B2);

        statistics.setBLID(blid);

        address[] memory path = new address[](2);
        path[0] = blid;
        path[1] = USDT;
        statistics.setBLIDSwap(uniswapV3Router, path);

        statistics.setPriceOracle(
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
        ); // USDC
        statistics.setPriceOracle(
            0xc2132D05D31c914a87C6611C10748AEb04B58e8F,
            0x0A6513e40db6EB1b165753AD52E80663aeA50545
        ); // USDT
        statistics.setPriceOracle(
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D
        ); // DAI
        statistics.setPriceOracle(
            0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6,
            0xc907E116054Ad103354f2D350FD2514433D57F6f
        ); // WBTC
        statistics.setPriceOracle(
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
            0xF9680D99D6C9589e2a93a78A04A279e509205945
        ); // WETH
        statistics.setPriceOracle(
            0xD6DF932A45C0f255f85145f286eA0b292B21C90B,
            0x72484B12719E23115761D5DA1646945632979bB6
        ); // AAVE
        statistics.setPriceOracle(
            0x172370d5Cd63279eFa6d502DAB29171933a610AF,
            0x336584C8E6Dc19637A5b36206B1c79923111b405
        ); // CRV
        statistics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        ); // MATIC

        // Logic
        strategyLogic1 = new DForceLogic();
        strategyLogic1.__LendingLogic_init(comptroller, rainMaker);

        strategyLogic1.setExpenseAddress(expense);
        strategyLogic1.setMultiLogicProxy(multiLogicProxy);
        strategyLogic1.setBLID(blid);
        strategyLogic1.setSwapGateway(address(swapGateway));

        strategyLogic1.approveTokenForSwap(address(swapGateway), blid);
        strategyLogic1.approveTokenForSwap(address(swapGateway), DF);
        strategyLogic1.approveTokenForSwap(address(swapGateway), USDC);
        logic1 = address(strategyLogic1);

        strategyLogic2 = new DForceLogic();
        strategyLogic2.__LendingLogic_init(comptroller, rainMaker);

        strategyLogic2.setExpenseAddress(expense);
        strategyLogic2.setMultiLogicProxy(multiLogicProxy);
        strategyLogic2.setBLID(blid);
        strategyLogic2.setSwapGateway(address(swapGateway));

        strategyLogic2.approveTokenForSwap(address(swapGateway), blid);
        strategyLogic2.approveTokenForSwap(address(swapGateway), DF);
        strategyLogic2.approveTokenForSwap(address(swapGateway), USDC);
        logic2 = address(strategyLogic2);

        strategyLogic3 = new DForceLogic();
        strategyLogic3.__LendingLogic_init(comptroller, rainMaker);

        strategyLogic3.setExpenseAddress(expense);
        strategyLogic3.setMultiLogicProxy(multiLogicProxy);
        strategyLogic3.setBLID(blid);
        strategyLogic3.setSwapGateway(address(swapGateway));

        strategyLogic3.approveTokenForSwap(address(swapGateway), blid);
        strategyLogic3.approveTokenForSwap(address(swapGateway), DF);
        strategyLogic3.approveTokenForSwap(address(swapGateway), USDC);
        logic3 = address(strategyLogic3);

        // strategy
        strategy1 = new LendBorrowLendStrategy();
        strategy1.__Strategy_init(comptroller, logic1);

        strategy1.setBLID(blid);
        strategy1.setMultiLogicProxy(multiLogicProxy);
        strategy1.setStrategyStatistics(address(statistics));
        strategy1.setCirclesCount(_circlesCount);
        strategy1.setAvoidLiquidationFactor(5);
        strategy1.setMinStorageAvailable(300000000);
        strategy1.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy1.setMinBLIDPerRewardsToken(0);
        strategyLogic1.setAdmin(address(strategy1));
        strategy1.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day
        strategy1.setMinStorageAvailable(10000);
        strategy1.setMinRewardsSwapLimit(1000000);

        strategy2 = new LendBorrowLendStrategy();
        strategy2.__Strategy_init(comptroller, logic2);

        strategy2.setBLID(blid);
        strategy2.setMultiLogicProxy(multiLogicProxy);
        strategy2.setStrategyStatistics(address(statistics));
        strategy2.setCirclesCount(_circlesCount);
        strategy2.setAvoidLiquidationFactor(5);
        strategy2.setMinStorageAvailable(300000000);
        strategy2.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy2.setMinBLIDPerRewardsToken(0);
        strategyLogic2.setAdmin(address(strategy2));
        strategy2.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day
        strategy2.setMinStorageAvailable(10000);
        strategy2.setMinRewardsSwapLimit(1000000);

        strategy3 = new LendBorrowLendStrategy();
        strategy3.__Strategy_init(comptroller, logic3);

        strategy3.setBLID(blid);
        strategy3.setMultiLogicProxy(multiLogicProxy);
        strategy3.setStrategyStatistics(address(statistics));
        strategy3.setCirclesCount(_circlesCount);
        strategy3.setAvoidLiquidationFactor(5);
        strategy3.setMinStorageAvailable(300000000);
        strategy3.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy3.setMinBLIDPerRewardsToken(0);
        strategyLogic3.setAdmin(address(strategy3));
        strategy3.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day
        strategy3.setMinStorageAvailable(10000);
        strategy3.setMinRewardsSwapLimit(1000000);

        // Storage init
        IStorageTest(_storage).setBLID(blid);
        IStorageTest(_storage).setMultiLogicProxy(address(multiLogic));
        IStorageTest(_storage).addToken(
            ZERO_ADDRESS,
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        );
        IStorageTest(_storage).addToken(
            USDT,
            0x0A6513e40db6EB1b165753AD52E80663aeA50545
        );
        IStorageTest(_storage).setOracleDeviationLimit(1 ether);

        // MultiLogicProxy Init
        MultiLogic.singleStrategy memory strategyInfo1;
        strategyInfo1.logicContract = logic1;
        strategyInfo1.strategyContract = address(strategy1);

        MultiLogic.singleStrategy memory strategyInfo2;
        strategyInfo2.logicContract = logic2;
        strategyInfo2.strategyContract = address(strategy2);

        string[] memory _strategyName = new string[](2);
        _strategyName[0] = "USDT_USDT";
        _strategyName[1] = "USDT_USDC";
        MultiLogic.singleStrategy[]
            memory _multiStrategy = new MultiLogic.singleStrategy[](2);
        _multiStrategy[0] = strategyInfo1;
        _multiStrategy[1] = strategyInfo2;

        multiLogic.initStrategies(_strategyName, _multiStrategy);

        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 4000;
        percentages[1] = 6000;
        multiLogic.setPercentages(USDT, percentages);

        // Storage init
        IStorageTest(_storage).setMultiLogicProxy(address(multiLogic));
        IERC20MetadataUpgradeable(USDT).approve(_storage, 10000000000);

        // Strategy 1 init
        strategy1.setStrategyXToken(iUSDT);
        strategy1.setSupplyXToken(iUSDT);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy1.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy1.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy1.setSwapInfo(swapInfo, 2);
        strategy1.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDT;
        strategy1.setSwapInfo(swapInfo, 3);

        // Strategy 2 init
        strategy2.setStrategyXToken(iUSDC);
        strategy2.setSupplyXToken(iUSDT);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy2.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy2.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy2.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        strategy2.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy2.setSwapInfo(swapInfo, 4);

        // Strategy 3 init
        strategy3.setStrategyXToken(iDAI);
        strategy3.setSupplyXToken(iUSDT);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy3.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = DAI;
        strategy3.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy3.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy3.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy3.setSwapInfo(swapInfo, 4);

        vm.stopPrank();
    }

    function test_Available() public {
        vm.startPrank(owner);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);

        console.log("---- Check token available ----");
        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Build strategy 1 ----");
        strategy1.useToken();
        strategy1.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Build strategy 2 ----");
        strategy2.useToken();
        strategy2.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 60000);

        console.log("---- Withdraw 50% ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);
        IStorageTest(_storage).withdraw(50000, USDT);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 20000);
        assertEq(_getBalance(logic2), 30000);

        console.log("---- Deposit 50% ----");
        IStorageTest(_storage).deposit(50000, USDT);

        assertEq(_getAvailable(logic1), 20000);
        assertEq(_getAvailable(logic2), 30000);
        assertEq(_getBalance(logic1), 20000);
        assertEq(_getBalance(logic2), 30000);

        console.log("---- DestroyAll strategy1 ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        strategy1.destroyAll();

        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 30000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 30000);

        console.log("---- DestroyAll strategy2 ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);
        strategy2.destroyAll();

        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Update percentage ----");

        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 5000;
        percentages[1] = 5000;
        multiLogic.setPercentages(USDT, percentages);

        assertEq(_getAvailable(logic1), 50000);
        assertEq(_getAvailable(logic2), 50000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Withdraw All ----");
        IStorageTest(_storage).withdraw(100000, USDT);

        vm.stopPrank();
    }

    function test_ReleaseOddDivision() public {
        vm.startPrank(owner);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);

        console.log("---- Update percentage 50/50 ----");
        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 5000;
        percentages[1] = 5000;
        multiLogic.setPercentages(USDT, percentages);

        console.log("---- Build strategy 1, 2 ----");
        strategy1.useToken();
        strategy1.rebalance();
        strategy2.useToken();
        strategy2.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 50000);
        assertEq(_getBalance(logic2), 50000);

        console.log("---- Withdraw odd number ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);
        IStorageTest(_storage).withdraw(49999, USDT);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 25001);
        assertEq(_getBalance(logic2), 25000);

        console.log("---- Withdraw even number ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        IStorageTest(_storage).withdraw(30000, USDT);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 10001);
        assertEq(_getBalance(logic2), 10000);

        console.log("---- Withdraw remained (odd) ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        IStorageTest(_storage).withdraw(20001, USDT);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        vm.stopPrank();
    }

    function test_AvailableOdd() public {
        vm.startPrank(owner);
        console.log("---- set percentage 50/50 ----");
        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 5000;
        percentages[1] = 5000;
        multiLogic.setPercentages(USDT, percentages);

        console.log("---- Deposit to storage (odd) ----");
        IStorageTest(_storage).deposit(99999, USDT);

        assertEq(_getAvailable(logic1), 49999);
        assertEq(_getAvailable(logic2), 50000);

        console.log("---- Withdraw storage (odd) ----");
        IStorageTest(_storage).withdraw(49999, USDT);

        assertEq(_getAvailable(logic1), 25000);
        assertEq(_getAvailable(logic2), 25000);

        console.log("---- Deposit storage (even) ----");
        IStorageTest(_storage).deposit(50000, USDT);

        assertEq(_getAvailable(logic1), 50000);
        assertEq(_getAvailable(logic2), 50000);

        console.log("---- Withdraw storage (odd) ----");
        IStorageTest(_storage).withdraw(49999, USDT);

        assertEq(_getAvailable(logic1), 25001);
        assertEq(_getAvailable(logic2), 25000);

        console.log("---- WithdrawAll storage (odd) ----");
        IStorageTest(_storage).withdraw(50001, USDT);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);

        vm.stopPrank();
    }

    function test_SetPercentageOddDivision() public {
        vm.startPrank(owner);

        console.log("---- Deposit to storage (odd) ----");
        IStorageTest(_storage).deposit(99999, USDT);

        console.log("---- set percentage 50/50 ----");
        uint256[] memory percentages = new uint256[](2);
        percentages[0] = 5000;
        percentages[1] = 5000;
        multiLogic.setPercentages(USDT, percentages);

        assertEq(_getAvailable(logic1), 49999);
        assertEq(_getAvailable(logic2), 50000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        vm.stopPrank();
    }

    function test_AddStrategy() public {
        vm.startPrank(owner);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);

        console.log("---- Check token available ----");
        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Build strategy 1 ----");
        strategy1.useToken();
        strategy1.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 0);

        console.log("---- Build strategy 2 ----");
        strategy2.useToken();
        strategy2.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 60000);

        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);
        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 60000);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 100000000000000000);

        console.log("---- Add new strategy ----");
        MultiLogic.singleStrategy memory strategyInfo3;
        strategyInfo3.logicContract = logic3;
        strategyInfo3.strategyContract = address(strategy3);
        multiLogic.addStrategy("USDT_DAI", strategyInfo3, false);

        assertEq(_getAvailable(logic1), 40000);
        assertEq(_getAvailable(logic2), 60000);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 60000);
        assertEq(_getBalance(logic3), 0);

        console.log("---- Update percentage ----");

        uint256[] memory percentages = new uint256[](3);
        percentages[0] = 5000;
        percentages[1] = 2000;
        percentages[2] = 3000;
        multiLogic.setPercentages(USDT, percentages);

        assertEq(_getAvailable(logic1), 60000);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getAvailable(logic3), 60000);
        assertEq(_getBalance(logic1), 40000);
        assertEq(_getBalance(logic2), 40000);
        assertEq(_getBalance(logic3), 0);
        assertEq(IERC20MetadataUpgradeable(USDT).balanceOf(_storage), 120000);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 120000000000000000);

        console.log("---- Use Token ----");
        strategy1.useToken();
        strategy2.useToken();
        strategy3.useToken();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 100000);
        assertEq(_getBalance(logic2), 40000);
        assertEq(_getBalance(logic3), 60000);

        console.log("---- Withdraw All ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        IStorageTest(_storage).withdraw(200000, USDT);

        vm.stopPrank();
    }

    function test_DeactivateStrategy() public {
        uint256[] memory percentages = new uint256[](3);

        vm.startPrank(owner);

        console.log("---- Add new strategy ----");
        MultiLogic.singleStrategy memory strategyInfo3;
        strategyInfo3.logicContract = logic3;
        strategyInfo3.strategyContract = address(strategy3);
        multiLogic.addStrategy("USDT_DAI", strategyInfo3, false);

        console.log("---- Update percentage ----");

        percentages[0] = 5000;
        percentages[1] = 2000;
        percentages[2] = 3000;
        multiLogic.setPercentages(USDT, percentages);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);

        console.log("---- Check token available ----");
        assertEq(_getAvailable(logic1), 50000);
        assertEq(_getAvailable(logic2), 20000);
        assertEq(_getAvailable(logic3), 30000);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);
        assertEq(_getBalance(logic3), 0);

        console.log("---- Build strategy ----");
        strategy1.useToken();
        strategy2.useToken();
        strategy3.useToken();
        strategy1.rebalance();
        strategy2.rebalance();
        strategy3.rebalance();

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 50000);
        assertEq(_getBalance(logic2), 20000);
        assertEq(_getBalance(logic3), 30000);

        console.log("---- Deposit to storage ----");
        IStorageTest(_storage).deposit(100000, USDT);

        assertEq(_getAvailable(logic1), 50000);
        assertEq(_getAvailable(logic2), 20000);
        assertEq(_getAvailable(logic3), 30000);
        assertEq(_getBalance(logic1), 50000);
        assertEq(_getBalance(logic2), 20000);
        assertEq(_getBalance(logic3), 30000);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 100000000000000000);

        console.log("---- Deactivate strategy ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        multiLogic.deactivateStrategy("USDT_DAI");

        percentages = multiLogic.getPercentage(USDT);
        assertEq(percentages[0], 7142);
        assertEq(percentages[1], 2858);
        assertEq(percentages[2], 0);

        assertEq(_getAvailable(logic1), 92840);
        assertEq(_getAvailable(logic2), 37160);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 50000);
        assertEq(_getBalance(logic2), 20000);
        assertEq(_getBalance(logic3), 0);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 130000000000000000);

        console.log("---- Deactivate strategy ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        multiLogic.deactivateStrategy("USDT_USDC");

        percentages = multiLogic.getPercentage(USDT);
        assertEq(percentages[0], 10000);
        assertEq(percentages[1], 0);
        assertEq(percentages[2], 0);

        assertEq(_getAvailable(logic1), 150000);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 50000);
        assertEq(_getBalance(logic2), 0);
        assertEq(_getBalance(logic3), 0);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 150000000000000000);

        console.log("---- Deactivate strategy ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        multiLogic.deactivateStrategy("USDT_USDT");

        percentages = multiLogic.getPercentage(USDT);
        assertEq(percentages[0], 0);
        assertEq(percentages[1], 0);
        assertEq(percentages[2], 0);

        assertEq(_getAvailable(logic1), 0);
        assertEq(_getAvailable(logic2), 0);
        assertEq(_getAvailable(logic3), 0);
        assertEq(_getBalance(logic1), 0);
        assertEq(_getBalance(logic2), 0);
        assertEq(_getBalance(logic3), 0);
        assertEq(IStorage(_storage).getTokenBalance(USDT), 200000000000000000);

        console.log("---- Withdraw All ----");
        vm.warp(block.timestamp + 2000);
        vm.roll(block.number + 999999);

        IStorageTest(_storage).withdraw(200000, USDT);

        vm.stopPrank();
    }

    function _getAvailable(address logic) private view returns (uint256) {
        return multiLogic.getTokenAvailable(USDT, logic);
    }

    function _getBalance(address logic) private view returns (uint256) {
        return multiLogic.getTokenTaken(USDT, logic);
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
