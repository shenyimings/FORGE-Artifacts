// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/SwapGateway.sol";
import "../../../contracts/MultiLogic.sol";
import "../../../contracts/strategies/lbl/dforce/DForceStatistics.sol";
import "../../../contracts/strategies/lbl/dforce/DForceLogic.sol";
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
    function deposit(uint256 amount, address token) external payable;

    function withdraw(uint256 amount, address token) external;

    function addToken(address _token, address _oracles) external;

    function setMultiLogicProxy(address) external;
}

contract DForceStrategyPolygonTest is Test {
    uint256 private mainnetFork;

    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    DForceStatistics public statistics;
    SwapGateway public swapGateway;

    DForceLogic strategyLogic;
    LendBorrowLendStrategy strategy;
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
    address logic;

    address iUSDT = 0xb3ab7148cCCAf66686AD6C1bE24D83e58E6a504e;
    address iUSDC = 0x5268b3c4afb0860D365a093C184985FCFcb65234;
    address iDAI = 0xec85F77104Ffa35a5411750d70eDFf8f1496d95b;
    address iwETH = 0x0c92617dF0753Af1CaB2d9Cc6A56173970d81740;
    address iMATIC = 0x6A3fE5342a4Bd09efcd44AC5B9387475A0678c74;
    address MATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address wETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address DF = 0x08C15FA26E519A78a666D19CE5C646D55047e0a3;

    uint256 _borrowRateMin = 600000000000000000;
    uint256 _borrowRateMax = 800000000000000000;
    uint8 _circlesCount = 10;
    address rewardsToken = DF;

    function setUp() public {
        mainnetFork = vm.createSelectFork(vm.rpcUrl("polygon"), BLOCK_NUMBER);
        vm.startPrank(owner);

        // MultiLogic
        MultiLogic multiLogic = new MultiLogic();
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
        strategyLogic = new DForceLogic();
        strategyLogic.__LendingLogic_init(comptroller, rainMaker);
        logic = address(strategyLogic);

        strategyLogic.setExpenseAddress(expense);
        strategyLogic.setMultiLogicProxy(multiLogicProxy);
        strategyLogic.setBLID(blid);
        strategyLogic.setSwapGateway(address(swapGateway));

        strategyLogic.approveTokenForSwap(address(swapGateway), blid);
        strategyLogic.approveTokenForSwap(address(swapGateway), DF);
        strategyLogic.approveTokenForSwap(address(swapGateway), USDC);

        // strategy
        strategy = new LendBorrowLendStrategy();
        strategy.__Strategy_init(comptroller, logic);

        strategy.setBLID(blid);
        strategy.setMultiLogicProxy(multiLogicProxy);
        strategy.setStrategyStatistics(address(statistics));
        strategy.setCirclesCount(_circlesCount);
        strategy.setAvoidLiquidationFactor(5);
        strategy.setMinStorageAvailable(300000000);
        strategy.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy.setMinBLIDPerRewardsToken(0);
        strategyLogic.setAdmin(address(strategy));
        strategy.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day

        // MultiLogicProxy Init

        MultiLogic.singleStrategy memory strategyInfo;
        strategyInfo.logicContract = logic;
        strategyInfo.strategyContract = address(strategy);
        string[] memory _strategyName = new string[](1);
        _strategyName[0] = "DF";
        MultiLogic.singleStrategy[]
            memory _multiStrategy = new MultiLogic.singleStrategy[](1);
        _multiStrategy[0] = strategyInfo;

        multiLogic.initStrategies(_strategyName, _multiStrategy);
        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 10000;
        multiLogic.setPercentages(USDT, percentages);
        multiLogic.setPercentages(ZERO_ADDRESS, percentages);

        // Storage init
        IStorageTest(_storage).setMultiLogicProxy(address(multiLogic));
        IStorageTest(_storage).addToken(
            ZERO_ADDRESS,
            0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        );
        IStorageTest(_storage).addToken(
            USDC,
            0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7
        );
        IStorageTest(_storage).addToken(
            DAI,
            0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D
        );
        IStorageTest(_storage).addToken(
            wETH,
            0xF9680D99D6C9589e2a93a78A04A279e509205945
        );

        // Deal and swap USDC, ETH, DAI, USDT
        vm.deal(owner, 10**21);

        path = new address[](2);
        path[0] = ZERO_ADDRESS;
        path[1] = USDT;

        swapGateway.swap{value: 250 * 10**18}(
            uniswapV3Router,
            250 * 10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        path = new address[](2);
        path[0] = ZERO_ADDRESS;
        path[1] = USDC;

        swapGateway.swap{value: 250 * 10**18}(
            uniswapV3Router,
            250 * 10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = USDC;
        path[2] = wETH;

        swapGateway.swap{value: 250 * 10**18}(
            uniswapV3Router,
            250 * 10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = USDC;
        path[2] = DAI;

        swapGateway.swap{value: 250 * 10**18}(
            uniswapV3Router,
            250 * 10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        vm.stopPrank();
    }

    function test_USDT_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iUSDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDT;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iUSDT, USDT, iUSDT, USDT, 200000);

        vm.stopPrank();
    }

    function test_USDT_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iUSDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

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
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iUSDT, USDT, iUSDC, USDC, 200000);

        vm.stopPrank();
    }

    function test_MATIC_MATIC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iMATIC);
        strategy.setSupplyXToken(iMATIC);
        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = ZERO_ADDRESS;
        swapInfo.paths[0][3] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iMATIC, ZERO_ADDRESS, iMATIC, ZERO_ADDRESS, 10**18);

        vm.stopPrank();
    }

    function test_MATIC_DAI() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iDAI);
        strategy.setSupplyXToken(iMATIC);
        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = DAI;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iMATIC, ZERO_ADDRESS, iDAI, DAI, 10**18);

        vm.stopPrank();
    }

    function test_USDC_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iUSDC);
        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

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
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 3);

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
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iUSDC, USDC, iUSDC, USDC, 200 * 10**6);

        vm.stopPrank();
    }

    function test_USDC_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iUSDC);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 3);

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
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iUSDC, USDC, iUSDT, USDT, 200 * 10**6);

        vm.stopPrank();
    }

    function test_ETH_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iwETH);

        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

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
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = wETH;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = wETH;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iwETH, wETH, iUSDC, USDC, 5 * 10**16);

        vm.stopPrank();
    }

    function test_ETH_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iwETH);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = wETH;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = wETH;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iwETH, wETH, iUSDT, USDT, 5 * 10**16);

        vm.stopPrank();
    }

    function test_MATIC_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iMATIC);

        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

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
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iMATIC, ZERO_ADDRESS, iUSDC, USDC, 10**18);

        vm.stopPrank();
    }

    function test_MATIC_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iMATIC);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.swapRouters[1] = quickswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDT;
        swapInfo.paths[1][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iMATIC, ZERO_ADDRESS, iUSDT, USDT, 10**18);

        vm.stopPrank();
    }

    function test_DAI_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iDAI);

        strategyLogic.approveTokenForSwap(address(swapGateway), USDT);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

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
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = DAI;
        strategy.setSwapInfo(swapInfo, 3);

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
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iDAI, DAI, iUSDC, USDC, 20 * 10**18);

        vm.stopPrank();
    }

    function test_DAI_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iDAI);

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
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = quickswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = DAI;
        strategy.setSwapInfo(swapInfo, 3);

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
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iDAI, DAI, iUSDT, USDT, 20 * 10**18);

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
        XTokenInfo memory supplyTokenInfo;

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
            vm.warp(block.timestamp + 2000);
            vm.roll(block.number + 999999);

            blidExpense = IERC20MetadataUpgradeable(blid).balanceOf(expense);
            blidStorage = IERC20MetadataUpgradeable(blid).balanceOf(_storage);

            console.log("BLID of expense   : ", blidExpense);
            console.log("BLID of storage   : ", blidStorage);

            console.log("-- After Claim with small DF amount --");
            strategy.setMinRewardsSwapLimit(10**25);
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
                supplyTokenInfo = statistics.getStrategyXTokenInfo(
                    supplyXToken,
                    logic
                );
                assertEq(
                    int256(supplyTokenInfo.lendingAmountUSD) -
                        int256(supplyTokenInfo.totalSupplyUSD) -
                        int256(tokenInfo.totalSupplyUSD) +
                        int256(tokenInfo.borrowAmountUSD) <
                        int256(
                            2 *
                                10 **
                                    (18 -
                                        IERC20MetadataUpgradeable(strategyToken)
                                            .decimals())
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
                supplyTokenInfo = statistics.getStrategyXTokenInfo(
                    supplyXToken,
                    logic
                );
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

    function _initializeProxy() private view {
        /* Use UUPXProxy pattern for oppenzeppelin initializer
         * - in UpgradeableBse _initialize has "initializer" modifier
         * - in DForceLogic __Logic_init doesn't have "initializer" modifer
         * - import "../../../contracts/utils/UUPSProxy.sol";
         */
        // UUPSProxy dForceLogicProxy;
        // DForceLogic dForceLogicImpl;
        // DForceLogic strategyLogic;
        // dForceLogicImpl = new DForceLogic();
        // dForceLogicProxy = new UUPSProxy(address(dForceLogicImpl), "");
        // strategyLogic = DForceLogic(payable(address(dForceLogicProxy)));
    }
}
