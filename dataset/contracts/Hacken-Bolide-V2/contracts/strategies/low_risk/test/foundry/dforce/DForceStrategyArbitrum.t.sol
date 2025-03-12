// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../../contracts/utils/UUPSProxy.sol";
import "../../../contracts/SwapGateway.sol";
import "../../../contracts/MultiLogic.sol";
import "../../../contracts/StorageV3.sol";
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
    function setBLID(address) external;

    function deposit(uint256 amount, address token) external payable;

    function withdraw(uint256 amount, address token) external;

    function addToken(address _token, address _oracles) external;

    function setMultiLogicProxy(address) external;

    function setOracleDeviationLimit(uint256) external;
}

contract DForceStrategyArbitrumTest is Test {
    uint256 private mainnetFork;

    address owner = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    DForceStatistics public statistics;
    SwapGateway public swapGateway;

    DForceLogic strategyLogic;
    LendBorrowLendStrategy strategy;
    SwapInfo swapInfo;

    uint256 private constant BLOCK_NUMBER = 101_138_752;
    address private constant ZERO_ADDRESS = address(0);
    address expense = 0xa7e21fabEC16A185Acae3AB3d004DF84b23C3501;
    address comptroller = 0x8E7e9eA9023B81457Ae7E6D2a51b003D421E5408;
    address rainMaker = 0xF45e2ae152384D50d4e9b08b8A1f65F0d96786C3;
    address blid = 0x81dE4945807bb31425362F8F7109C18E3dc4f8F0;
    address uniswapV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address DODOV2Proxy02 = 0x88CBf433471A0CD8240D2a12354362988b4593E5;
    address DF_USX = 0x19E5910F61882Ff6605b576922507F1E1A0302FE;
    address USX_USDC = 0x9340e3296121507318874ce9C04AFb4492aF0284;
    address multiLogicProxy;
    address _storage;
    address logic;

    address iUSDT = 0xf52f079Af080C9FB5AFCA57DDE0f8B83d49692a9;
    address iETH = 0xEe338313f022caee84034253174FA562495dcC15;
    address iUSDC = 0x8dc3312c68125a94916d62B97bb5D925f84d4aE0;
    address iDAI = 0xf6995955e4B0E5b287693c221f456951D612b628;
    address ETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address USX = 0x641441c631e2F909700d2f41FD87F0aA6A6b4EDb;
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address DF = 0xaE6aab43C4f3E0cea4Ab83752C278f8dEbabA689;
    address iDF = 0xaEa8e2e7C97C5B7Cd545d3b152F669bAE29C4a63;

    uint256 _borrowRateMin = 600000000000000000;
    uint256 _borrowRateMax = 800000000000000000;
    uint8 _circlesCount = 10;
    address rewardsToken = DF;

    function setUp() public {
        mainnetFork = vm.createSelectFork(
            "https://delicate-fittest-river.arbitrum-mainnet.quiknode.pro/f9bd07b0a038b381579406e63d23faf83f28eda6/",
            BLOCK_NUMBER
        );
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
        swapGateway.addSwapRouter(DODOV2Proxy02, 4);
        swapGateway.addSwapRouter(uniswapV3Router, 3);

        swapGateway.setWETH(ETH);

        // Statistics
        statistics = new DForceStatistics();
        statistics.__StrategyStatistics_init();
        statistics.setSwapGateway(address(swapGateway));
        statistics.setRewardsXToken(iDF);

        statistics.setBLID(blid);

        address[] memory path = new address[](2);
        path[0] = blid;
        path[1] = USDT;
        statistics.setBLIDSwap(uniswapV3Router, path);

        statistics.setPriceOracle(
            USDT,
            0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7
        ); // USDT

        statistics.setPriceOracle(
            USX_USDC,
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
        ); // USX_USDC

        statistics.setPriceOracle(
            0x0000000000000000000000000000000000000000,
            0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
        ); // ETH

        statistics.setPriceOracle(
            USDC,
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
        ); // USDC

        // strategyLogic
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

        strategy.setMinStorageAvailable(3 * 10**18);
        strategy.setRebalanceParameter(_borrowRateMin, _borrowRateMax);
        strategy.setMinBLIDPerRewardsToken(0);
        strategyLogic.setAdmin(address(strategy));
        strategy.setRewardsTokenPriceDeviationLimit(
            (1 ether) / uint256(100 * 86400)
        ); // 1% / 1day

        // MultiLogicProxy Init
        MultiLogic.singleStrategy memory strategyInfoDForce;
        strategyInfoDForce.logicContract = logic;
        strategyInfoDForce.strategyContract = address(strategy);

        string[] memory _strategyName = new string[](1);
        _strategyName[0] = "DForce";
        MultiLogic.singleStrategy[]
            memory _multiStrategy = new MultiLogic.singleStrategy[](1);
        _multiStrategy[0] = strategyInfoDForce;

        multiLogic.initStrategies(_strategyName, _multiStrategy);
        uint256[] memory percentages = new uint256[](1);
        percentages[0] = 10000;
        multiLogic.setPercentages(USDT, percentages);
        multiLogic.setPercentages(ZERO_ADDRESS, percentages);

        // Storage init
        IStorageTest(_storage).setBLID(blid);
        IStorageTest(_storage).setMultiLogicProxy(address(multiLogic));
        IStorageTest(_storage).addToken(
            ZERO_ADDRESS,
            0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
        );
        IStorageTest(_storage).addToken(
            USDT,
            0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7
        );
        IStorageTest(_storage).addToken(
            USDC,
            0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3
        );
        IStorageTest(_storage).addToken(
            DAI,
            0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB
        );

        IStorageTest(_storage).setOracleDeviationLimit(1 ether);

        // Deal and swap USDT
        vm.deal(owner, 10**18);

        path = new address[](2);
        path[0] = ZERO_ADDRESS;
        path[1] = USDT;

        swapGateway.swap{value: 10**18}(
            uniswapV3Router,
            10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        // Deal and swap USDC
        vm.deal(owner, 10**18);

        path = new address[](2);
        path[0] = ZERO_ADDRESS;
        path[1] = USDC;

        swapGateway.swap{value: 10**18}(
            uniswapV3Router,
            10**18,
            0,
            path,
            true,
            block.timestamp + 3600
        );

        // Deal and swap DAI
        vm.deal(owner, 10**18);

        path = new address[](3);
        path[0] = ZERO_ADDRESS;
        path[1] = USDC;
        path[2] = DAI;

        swapGateway.swap{value: 10**18}(
            uniswapV3Router,
            10**18,
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
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = USDT;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iUSDT, USDT, iUSDT, USDT, 2 * 10**6);

        vm.stopPrank();
    }

    function xtest_USDT_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iUSDT);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDT;
        swapInfo.paths[0][1] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iUSDT, USDT, iUSDC, USDC, 2 * 10**6);

        vm.stopPrank();
    }

    function test_USDC_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iUSDC);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDC;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iUSDC, USDC, iUSDC, USDC, 2 * 10**6);

        vm.stopPrank();
    }

    function xtest_USDC_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iUSDC);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
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

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iUSDC, USDC, iUSDT, USDT, 2 * 10**6);

        vm.stopPrank();
    }

    function xtest_DAI_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iDAI);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
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

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iDAI, DAI, iUSDT, USDT, 2 * 10**18);

        vm.stopPrank();
    }

    function xtest_DAI_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iDAI);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = DAI;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iDAI, DAI, iUSDC, USDC, 2 * 10**18);

        vm.stopPrank();
    }

    function test_DAI_DAI() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iDAI);
        strategy.setSupplyXToken(iDAI);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = DAI;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = USDC;
        swapInfo.paths[0][2] = USDT;
        swapInfo.paths[0][3] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = DAI;
        swapInfo.paths[0][1] = DAI;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iDAI, DAI, iDAI, DAI, 2 * 10**18);

        vm.stopPrank();
    }

    function xtest_ETH_USDT() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDT);
        strategy.setSupplyXToken(iETH);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
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

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iETH, ZERO_ADDRESS, iUSDT, USDT, 2 * 10**18);

        vm.stopPrank();
    }

    function xtest_ETH_USDC() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iUSDC);
        strategy.setSupplyXToken(iETH);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 2);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = USDC;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 4);

        _testStrategy(iETH, ZERO_ADDRESS, iUSDC, USDC, 2 * 10**18);

        vm.stopPrank();
    }

    function test_ETH_ETH() public {
        vm.startPrank(owner);

        // Configuration
        strategy.setStrategyXToken(iETH);
        strategy.setSupplyXToken(iETH);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](3);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = USDT;
        swapInfo.paths[1][2] = blid;
        strategy.setSwapInfo(swapInfo, 0);

        swapInfo.swapRouters = new address[](2);
        swapInfo.swapRouters[0] = DODOV2Proxy02;
        swapInfo.swapRouters[1] = uniswapV3Router;
        swapInfo.paths = new address[][](2);
        swapInfo.paths[0] = new address[](4);
        swapInfo.paths[0][0] = DF;
        swapInfo.paths[0][1] = DF_USX;
        swapInfo.paths[0][2] = USX_USDC;
        swapInfo.paths[0][3] = USDC;
        swapInfo.paths[1] = new address[](2);
        swapInfo.paths[1][0] = USDC;
        swapInfo.paths[1][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 1);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](3);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = USDT;
        swapInfo.paths[0][2] = blid;
        strategy.setSwapInfo(swapInfo, 2);
        strategy.setSwapInfo(swapInfo, 4);

        swapInfo.swapRouters = new address[](1);
        swapInfo.swapRouters[0] = uniswapV3Router;
        swapInfo.paths = new address[][](1);
        swapInfo.paths[0] = new address[](2);
        swapInfo.paths[0][0] = ZERO_ADDRESS;
        swapInfo.paths[0][1] = ZERO_ADDRESS;
        strategy.setSwapInfo(swapInfo, 3);

        _testStrategy(iETH, ZERO_ADDRESS, iETH, ZERO_ADDRESS, 2 * 10**18);

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
            strategy.setMinRewardsSwapLimit(10**30);
            strategy.claimRewards();

            if (false) {
                strategy.setMinRewardsSwapLimit(10**2);
                address[] memory holders = new address[](1);
                holders[0] = logic;
                address[] memory supplys = new address[](2);
                supplys[0] = supplyXToken;
                supplys[1] = strategyXToken;
                address[] memory borrows = new address[](1);
                borrows[0] = strategyXToken;
                IDistributionDForce(rainMaker).claimRewards(
                    holders,
                    supplys,
                    borrows
                );
                console.log(IERC20MetadataUpgradeable(DF).balanceOf(logic));
                return;
            }

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
            _showXTokenInfo();
            console.log("------");
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
                        2,
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
                        int256(
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
