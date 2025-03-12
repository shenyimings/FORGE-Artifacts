// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";
import { ERC20 }              from "../../modules/erc20/contracts/ERC20.sol";
import { MockERC20 }          from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { Liquidator }            from "../Liquidator.sol";
import { LiquidatorFactory }     from "../LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../LiquidatorInitializer.sol";

import { SushiswapStrategy } from "../strategies/SushiswapStrategy.sol";
import { UniswapV2Strategy } from "../strategies/UniswapV2Strategy.sol";

import {
    FailApproveERC20,
    MaliciousERC20,
    MockFactory,
    MockGlobals,
    MockLoanManager,
    MockMigrator,
    Rebalancer,
    ReentrantLiquidator
} from "./mocks/Mocks.sol";

contract LiquidatorTestBase is TestUtils {

    address governor;
    address poolDelegate;
    address profitDestination;

    address sushiswapRouterV2;
    address uniswapRouterV2;
    address usdcOracle;
    address wethOracle;

    address implementation;
    address initializer;

    // Helper state variable to avoid infinite loops when using the modifier.
    bool locked;

    ERC20 usdc;
    ERC20 weth;

    MockFactory     loanManagerFactory;
    MockGlobals     globals;
    MockLoanManager benchmarkLoanManager;
    MockLoanManager loanManager;

    Liquidator          benchmarkLiquidator;
    Liquidator          liquidator;
    LiquidatorFactory   liquidatorFactory;
    Rebalancer          rebalancer;
    ReentrantLiquidator reentrantLiquidator;

    UniswapV2Strategy uniswapStrategy;
    SushiswapStrategy sushiswapStrategy;

    modifier assertFailureWhenPaused() {
        if (!locked) {
            locked = true;

            globals.__setProtocolPaused(true);

            ( bool success, ) = address(this).call(msg.data);

            assertTrue(!success || failed, "test should have failed when paused");

            globals.__setProtocolPaused(false);
        }

        _;

        locked = false;
    }

    /******************************************************************************************************************************/
    /*** Setup Functions                                                                                                        ***/
    /******************************************************************************************************************************/

    function setUp() public virtual {
        _linkContracts();
        _createAccounts();
        _createGlobals();
        _createLoanManagerFactory();
        _createLoanManagers();
        _createLiquidators();
        _createStrategies();
    }

    function _createAccounts() internal {
        governor          = address(new Address());
        poolDelegate      = address(new Address());
        profitDestination = address(new Address());
    }

    function _createGlobals() internal {
        globals = new MockGlobals(address(governor));
        globals.__setPriceOracle(address(usdc), usdcOracle);
        globals.__setPriceOracle(address(weth), wethOracle);
    }

    function _createLiquidators() internal {
        vm.startPrank(governor);
        liquidatorFactory = new LiquidatorFactory(address(globals));
        implementation    = address(new Liquidator());
        initializer       = address(new LiquidatorInitializer());
        liquidatorFactory.registerImplementation(1, implementation, initializer);
        liquidatorFactory.setDefaultVersion(1);
        vm.stopPrank();

        vm.startPrank(address(loanManager));
        liquidator          = Liquidator(liquidatorFactory.createInstance(abi.encode(address(loanManager),          address(weth), address(usdc)), "loan-1"));
        benchmarkLiquidator = Liquidator(liquidatorFactory.createInstance(abi.encode(address(benchmarkLoanManager), address(weth), address(usdc)), "loan-2"));
        vm.stopPrank();

        rebalancer          = new Rebalancer();
        reentrantLiquidator = new ReentrantLiquidator();
    }

    function _createLoanManagerFactory() internal {
        loanManagerFactory = new MockFactory();

        globals.__setFactory("LOAN_MANAGER", address(loanManagerFactory), true);
    }

    function _createLoanManagers() internal {
        loanManager = new MockLoanManager(address(globals), address(usdc), address(poolDelegate));
        loanManager.__setFactory(address(loanManagerFactory));
        loanManager.__setValuesFor(address(weth), 200, 2_000 * 10 ** 6);  // 2% slippage allowed from market price

        benchmarkLoanManager = new MockLoanManager(address(globals), address(usdc), address(poolDelegate));
        benchmarkLoanManager.__setFactory(address(loanManagerFactory));
        benchmarkLoanManager.__setValuesFor(address(weth), 10_000, 0);

        loanManagerFactory.__setInstance(address(loanManager),          true);
        loanManagerFactory.__setInstance(address(benchmarkLoanManager), true);
    }

    function _createStrategies() internal {
        uniswapStrategy   = new UniswapV2Strategy();
        sushiswapStrategy = new SushiswapStrategy();
    }

    function _linkContracts() internal {
        usdc = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        weth = ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

        sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
        uniswapRouterV2   = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        usdcOracle        = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        wethOracle        = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    }

}

contract LiquidatorMigrateTests is LiquidatorTestBase {

    address migrator;

    function setUp() public override {
        super.setUp();

        migrator = address(new MockMigrator());
    }

    function test_migrate_notFactory() external {
        vm.expectRevert("LIQ:M:NOT_FACTORY");
        liquidator.migrate(migrator, "");
    }

    function test_migrate_internalFailure() external {
        vm.prank(address(liquidatorFactory));
        vm.expectRevert("LIQ:M:FAILED");
        liquidator.migrate(migrator, "");
    }

    function test_migrate_success() external {
        assertEq(liquidator.collateralAsset(), address(weth));

        vm.prank(address(liquidatorFactory));
        liquidator.migrate(migrator, abi.encode(address(usdc)));

        assertEq(liquidator.collateralAsset(), address(usdc));
    }

}

contract LiquidatorSetImplementationTests is LiquidatorTestBase {

    address newImplementation;

    function setUp() public override {
        super.setUp();

        newImplementation = address(new Liquidator());
    }

    function test_setImplementation_notFactory() external {
        vm.expectRevert("LIQ:SI:NOT_FACTORY");
        liquidator.setImplementation(newImplementation);
    }

    function test_setImplementation_success() external {
        assertEq(liquidator.implementation(), implementation);

        vm.prank(address(liquidatorFactory));
        liquidator.setImplementation(newImplementation);

        assertEq(liquidator.implementation(), newImplementation);
    }

}

contract LiquidatorUpgradeTests is LiquidatorTestBase {

    address migrator;
    address newImplementation;

    function setUp() public override {
        super.setUp();

        migrator          = address(new MockMigrator());
        newImplementation = address(new Liquidator());

        vm.startPrank(governor);
        liquidatorFactory.registerImplementation(2, newImplementation, initializer);
        liquidatorFactory.enableUpgradePath(1, 2, migrator);
        vm.stopPrank();
    }

    function test_upgrade_notAuthorized() external {
        vm.expectRevert("LIQ:U:NOT_AUTHORIZED");
        liquidator.upgrade(2, "");
    }

    function test_upgrade_notScheduled() external {
        vm.prank(poolDelegate);
        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        liquidator.upgrade(2, "");
    }

    function test_upgrade_withGovernor() external {
        MockGlobals(globals).__setIsValidScheduledCall(false);

        assertEq(liquidator.implementation(), implementation);

        vm.prank(governor);
        liquidator.upgrade(2, abi.encode(address(usdc)));

        assertEq(liquidator.implementation(),  address(newImplementation));
        assertEq(liquidator.collateralAsset(), address(usdc));
    }

    function test_upgrade_withPoolDelegate() external {
        MockGlobals(globals).__setIsValidScheduledCall(true);

        assertEq(liquidator.implementation(), implementation);

        vm.prank(poolDelegate);
        liquidator.upgrade(2, abi.encode(address(usdc)));

        assertEq(liquidator.implementation(),  address(newImplementation));
        assertEq(liquidator.collateralAsset(), address(usdc));
    }

}

contract LiquidatorPullFundsTest is LiquidatorTestBase {

    function test_pullFunds_notLoanManager() external {
        vm.expectRevert("LIQ:PF:NOT_LM");
        liquidator.pullFunds(address(weth), address(poolDelegate), 1);
    }

    function test_pullFunds_transferFailure() external {
        vm.prank(address(loanManager));
        vm.expectRevert("LIQ:PF:TRANSFER");
        liquidator.pullFunds(address(weth), address(poolDelegate), 1);
    }

    function test_pullFunds_success() external {
        erc20_mint(address(weth), 3, address(liquidator), 1);

        assertEq(weth.balanceOf(address(liquidator)),   1);
        assertEq(weth.balanceOf(address(poolDelegate)), 0);

        vm.prank(address(loanManager));
        liquidator.pullFunds(address(weth), address(poolDelegate), 1);

        assertEq(weth.balanceOf(address(liquidator)),   0);
        assertEq(weth.balanceOf(address(poolDelegate)), 1);
    }

}

contract LiquidatorUniswapTest is LiquidatorTestBase {

    function test_liquidator_uniswapStrategy() assertFailureWhenPaused public {
        erc20_mint(address(weth), 3, address(liquidator),          1_000 ether);
        erc20_mint(address(weth), 3, address(benchmarkLiquidator), 1_000 ether);
        erc20_mint(address(usdc), 9, address(rebalancer),          type(uint256).max);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(1_000 ether);

        vm.prank(benchmarkLiquidator.loanManager());
        benchmarkLiquidator.setCollateralRemaining(1_000 ether);

        uint256 returnAmount = liquidator.getExpectedAmount(1_000 ether);

        assertEq(returnAmount, 3_301_495_281785);  // $3.3m

        assertEq(weth.balanceOf(address(liquidator)),        1_000 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        // Try liquidating amount that is above slippage requirements
        try uniswapStrategy.flashBorrowLiquidation(address(liquidator), 485 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}

        // Function reverts if returnAmount is larger than maxReturnAmount
        try uniswapStrategy.flashBorrowLiquidation(address(liquidator), 485 ether, 1, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}

        /******************************************************************************************************************************/
        /*** First Liquidation                                                                                                      ***/
        /******************************************************************************************************************************/

        uint256 returnAmount1 = liquidator.getExpectedAmount(483 ether);
        assertEq(returnAmount1, 1_594_622_221102);  // $1.59m

        uniswapStrategy.flashBorrowLiquidation(address(liquidator), 483 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        517 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 13_001643);

        assertEq(liquidator.collateralRemaining(), 517 ether);

        /******************************************************************************************************************************/
        /*** Second Liquidation                                                                                                     ***/
        /******************************************************************************************************************************/

        rebalancer.swap(uniswapRouterV2, 483 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        uint256 returnAmount2 = liquidator.getExpectedAmount(250 ether);
        assertEq(returnAmount2, 825_373_820446);  // $825k

        uniswapStrategy.flashBorrowLiquidation(address(liquidator), 250 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        267 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 6_047_538289);

        assertEq(liquidator.collateralRemaining(), 267 ether);

        /******************************************************************************************************************************/
        /*** Third Liquidation                                                                                                      ***/
        /******************************************************************************************************************************/

        rebalancer.swap(uniswapRouterV2, 250 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        uint256 returnAmount3 = liquidator.getExpectedAmount(267 ether);
        assertEq(returnAmount3, 881_499_240236);  // $881k

        uniswapStrategy.flashBorrowLiquidation(address(liquidator), 267 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2 + returnAmount3);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 12_066_770467);

        assertEq(liquidator.collateralRemaining(), 0);

        /******************************************************************************************************************************/
        /*** Benchmark Liquidation                                                                                                  ***/
        /******************************************************************************************************************************/

        rebalancer.swap(uniswapRouterV2, 267 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 1000 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),     0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),     0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 1000 ether);

        uniswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 1000 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapStrategy)),     0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 3_250_485_553902);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),     0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 0 ether);

        assertEq(3_250_485_553902 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.984549507562998447 ether);  // ~ 1.5% savings on $3.3m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_uniswapStrategy_largeLiquidation() assertFailureWhenPaused public {
        erc20_mint(address(weth), 3, address(liquidator),          10_000 ether);  // ~$340m to liquidate
        erc20_mint(address(weth), 3, address(benchmarkLiquidator), 10_000 ether);
        erc20_mint(address(usdc), 9, address(rebalancer),          type(uint256).max);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(10_000 ether);

        vm.prank(benchmarkLiquidator.loanManager());
        benchmarkLiquidator.setCollateralRemaining(10_000 ether);

        assertEq(weth.balanceOf(address(liquidator)),        10_000 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        assertEq(liquidator.collateralRemaining(), 10_000 ether);

        /******************************************************************************************************************************/
        /*** Piecewise Liquidations                                                                                                 ***/
        /******************************************************************************************************************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            uniswapStrategy.flashBorrowLiquidation(address(liquidator), swapAmount, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

            rebalancer.swap(uniswapRouterV2, swapAmount, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_17844);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 66_683_168893);

        assertEq(liquidator.collateralRemaining(), 0);

        /******************************************************************************************************************************/
        /*** Benchmark Liquidation                                                                                                  ***/
        /******************************************************************************************************************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 10_000 ether);
        assertEq(weth.balanceOf(address(uniswapStrategy)),     0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),     0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 10_000 ether);

        uniswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 10_000 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(uniswapStrategy)),     0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 25_590_976_821869);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),     0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 0);

        assertEq(uint256(25_590_976_821869) * 10 ** 18 / uint256(330_149_528_17844), 0.775132921227060732 ether);  // ~22.4% savings on $340m liquidation
    }

}

contract LiquidatorSushiswapTest is LiquidatorTestBase {

    function test_liquidator_sushiswapStrategy() assertFailureWhenPaused public {
        erc20_mint(address(weth), 3, address(liquidator),          2_000 ether);
        erc20_mint(address(weth), 3, address(benchmarkLiquidator), 2_000 ether);
        erc20_mint(address(usdc), 9, address(rebalancer),          type(uint256).max);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(2_000 ether);

        vm.prank(benchmarkLiquidator.loanManager());
        benchmarkLiquidator.setCollateralRemaining(2_000 ether);

        uint256 returnAmount = liquidator.getExpectedAmount(2_000 ether);

        assertEq(returnAmount, 6_602_990_563570);  // $6.6m

        assertEq(weth.balanceOf(address(liquidator)),        2_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        assertEq(liquidator.collateralRemaining(), 2_000 ether);

        // Try liquidating amount that is above slippage requirements
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 1000 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}

        // Function reverts if returnAmount is larger than maxReturnAmount
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 1000 ether, 1, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}

        /******************************************************************************************************************************/
        /*** First Liquidation                                                                                                      ***/
        /******************************************************************************************************************************/

        uint256 returnAmount1 = liquidator.getExpectedAmount(950 ether);
        assertEq(returnAmount1, 3_136_420_517695);  // $1.59m

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        1050 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 2_366_149563);

        assertEq(liquidator.collateralRemaining(), 1050 ether);

        /******************************************************************************************************************************/
        /*** Second Liquidation                                                                                                    ***/
        /******************************************************************************************************************************/

        rebalancer.swap(sushiswapRouterV2, 950 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        uint256 returnAmount2 = liquidator.getExpectedAmount(950 ether);
        assertEq(returnAmount2, 3_136_420_517695);  // $825k

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, address(weth),  address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        100 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 5_039_959806);

        assertEq(liquidator.collateralRemaining(), 100 ether);

        /******************************************************************************************************************************/
        /*** Third Liquidation                                                                                                      ***/
        /******************************************************************************************************************************/

        rebalancer.swap(sushiswapRouterV2, 950 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        uint256 returnAmount3 = liquidator.getExpectedAmount(100 ether);
        assertEq(returnAmount3, 330_149_528178);  // $881k

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 100 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        returnAmount1 + returnAmount2 + returnAmount3);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 10_233_419098);

        assertEq(liquidator.collateralRemaining(), 0);

        /******************************************************************************************************************************/
        /*** Benchmark Liquidation                                                                                                  ***/
        /******************************************************************************************************************************/

        rebalancer.swap(sushiswapRouterV2, 50 ether, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 2_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 2_000 ether);

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 2_000 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 6_481_487_535049);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 0);

        assertEq(6_481_487_535049 * 10 ** 18 / (returnAmount1 + returnAmount2 + returnAmount3), 0.981598788102258853 ether);  // ~ 1.9% savings on $6.6m liquidation, will do larger liquidations in another test
    }

    function test_liquidator_sushiswapStrategy_largeLiquidation() public assertFailureWhenPaused {
        erc20_mint(address(weth), 3, address(liquidator),          10_000 ether);  // ~$340m to liquidate
        erc20_mint(address(weth), 3, address(benchmarkLiquidator), 10_000 ether);
        erc20_mint(address(usdc), 9, address(rebalancer),          type(uint256).max);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(10_000 ether);

        vm.prank(benchmarkLiquidator.loanManager());
        benchmarkLiquidator.setCollateralRemaining(10_000 ether);

        assertEq(weth.balanceOf(address(liquidator)),        10_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        assertEq(liquidator.collateralRemaining(), 10_000 ether);

        /******************************************************************************************************************************/
        /*** Piecewise Liquidations                                                                                                 ***/
        /******************************************************************************************************************************/

        while(weth.balanceOf(address(liquidator)) > 0) {
            uint256 swapAmount = weth.balanceOf(address(liquidator)) > 450 ether ? 450 ether : weth.balanceOf(address(liquidator));  // Stay within 2% slippage

            sushiswapStrategy.flashBorrowLiquidation(address(liquidator), swapAmount, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

            rebalancer.swap(sushiswapRouterV2, swapAmount, type(uint256).max, address(usdc), address(0), address(weth));  // Perform fake arbitrage transaction to get price back up
        }

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(liquidator)),        330_149_528_17844);  // Note that this is the exact same as the uniswap liquidation test, because the return amounts are the same.
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(profitDestination)), 328_752_316354);

        assertEq(liquidator.collateralRemaining(), 0);

        /******************************************************************************************************************************/
        /*** Benchmark Liquidation                                                                                                  ***/
        /******************************************************************************************************************************/

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 10_000 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 10_000 ether);

        sushiswapStrategy.flashBorrowLiquidation(address(benchmarkLiquidator), 10_000 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), address(benchmarkLiquidator));  // Send profits to benchmark liquidator

        assertEq(weth.balanceOf(address(benchmarkLiquidator)), 0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(benchmarkLiquidator)), 28_637_543_873315);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)),   0);

        assertEq(benchmarkLiquidator.collateralRemaining(), 0 ether);

        assertEq(uint256(28_637_543_873315) * 10 ** 18 / uint256(330_149_528_17844), 0.867411322115744850 ether);  // ~13.2% savings on $34m liquidation
    }

}

contract LiquidatorMultipleAMMTest is LiquidatorTestBase {

    function test_liquidator_multipleStrategies() public assertFailureWhenPaused {
        erc20_mint(address(weth), 3, address(liquidator), 1_400 ether);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(1_400 ether);

        assertEq(weth.balanceOf(address(liquidator)),        1_400 ether);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);

        assertEq(usdc.balanceOf(address(liquidator)),        0);
        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 0);

        assertEq(liquidator.collateralRemaining(), 1_400 ether);

        // Try liquidating amounts that are above slippage requirements (determined with while loop)
        try sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 995 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}
        try uniswapStrategy.flashBorrowLiquidation(address(liquidator), 484 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination) { fail(); } catch {}

        /******************************************************************************************************************************/
        /*** Multi-Strategy Liquidation                                                                                             ***/
        /******************************************************************************************************************************/

        uint256 returnAmount = liquidator.getExpectedAmount(1_400 ether);
        assertEq(returnAmount, 4_622_093_394499);  // $4.62m

        sushiswapStrategy.flashBorrowLiquidation(address(liquidator), 950 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);
        uniswapStrategy.flashBorrowLiquidation(address(liquidator), 450 ether, type(uint256).max, 0, address(weth), address(0), address(usdc), profitDestination);

        assertEq(weth.balanceOf(address(liquidator)),        0);
        assertEq(weth.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(weth.balanceOf(address(uniswapStrategy)),   0);

        assertEq(liquidator.collateralRemaining(), 0 ether);

        assertWithinDiff(usdc.balanceOf(address(liquidator)), returnAmount, 1);

        assertEq(usdc.balanceOf(address(sushiswapStrategy)), 0);
        assertEq(usdc.balanceOf(address(uniswapStrategy)),   0);
        assertEq(usdc.balanceOf(address(profitDestination)), 3_886_663971);
    }

}

contract LiquidatorOTCTest is LiquidatorTestBase {

    function test_eoa_otc_liquidation() public assertFailureWhenPaused {
        erc20_mint(address(weth), 3, address(liquidator), 1_400 ether);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(1_400 ether);

        uint256 returnAmount1 = liquidator.getExpectedAmount(1_400 ether);

        assertEq(returnAmount1, 4_622_093_394499);

        erc20_mint(address(usdc), 9, address(this), returnAmount1);

        // Starting state
        assertEq(weth.balanceOf(address(liquidator)), 1_400 ether);
        assertEq(weth.balanceOf(address(this)),       0);
        assertEq(usdc.balanceOf(address(liquidator)), 0);
        assertEq(usdc.balanceOf(address(this)),       returnAmount1);

        assertEq(liquidator.collateralRemaining(), 1_400 ether);

        usdc.approve(address(liquidator), returnAmount1 - 1);  // Approve for an amount less than the expected amount

        bytes memory arguments = new bytes(0);

        try liquidator.liquidatePortion(1_400 ether, type(uint256).max, arguments) { assertTrue(false, "Liquidation with less than approved amount"); } catch { }

        uint256 returnAmount2 = liquidator.getExpectedAmount(1_400 ether + 1);  // Return amount for over-liquidation

        assertEq(returnAmount2, returnAmount1);  // Small enough difference that return amounts are equal

        usdc.approve(address(liquidator), returnAmount1);  // Approve for the correct amount

        try liquidator.liquidatePortion(1_400 ether + 1, type(uint256).max, arguments) { assertTrue(false, "Liquidation for more than balance of liquidator"); } catch { }

        try liquidator.liquidatePortion(1_400 ether, returnAmount2 - 1, arguments) { assertTrue(false, "Liquidation for less than returnAmount"); } catch { }

        liquidator.liquidatePortion(1_400 ether, type(uint256).max, arguments);  // Successful when called with correct balance and approval

        // Ending state
        assertEq(weth.balanceOf(address(liquidator)), 0);
        assertEq(weth.balanceOf(address(this)),       1_400 ether);
        assertEq(usdc.balanceOf(address(liquidator)), returnAmount1);
        assertEq(usdc.balanceOf(address(this)),       0);

        assertEq(liquidator.collateralRemaining(), 0 ether);
    }

}

contract ReentrantLiquidatorTest is LiquidatorTestBase {

    function test_liquidator_reentrantStrategy() public {
        erc20_mint(address(weth), 3, address(liquidator), 1_400 ether);

        vm.prank(liquidator.loanManager());
        liquidator.setCollateralRemaining(1_400 ether);

        try reentrantLiquidator.flashBorrowLiquidation(address(liquidator), 1_400 ether) { assertTrue(false, "Liquidation with less than approved amount"); } catch { }
    }

}

contract MaliciousAssetTest is LiquidatorTestBase {

    MaliciousERC20 maliciousAsset;
    MaliciousERC20 maliciousCollateralAsset;
    Liquidator     maliciousLiquidator;

    function setUp() public override {
        super.setUp();

        maliciousAsset           = new MaliciousERC20();
        maliciousCollateralAsset = new MaliciousERC20();

        // Create a malicious asset based liquidator
        vm.prank(address(loanManager));
        maliciousLiquidator = Liquidator(liquidatorFactory.createInstance(abi.encode(address(loanManager), address(maliciousCollateralAsset), address(maliciousAsset)), "loan-3"));
    }

    function test_liquidatePortion_maliciousAsset() public {
        vm.expectRevert("LIQ:LP:INVALID_CALLER");
        maliciousAsset.transferAndCall(address(maliciousLiquidator));

        vm.expectRevert("LIQ:LP:INVALID_CALLER");
        maliciousCollateralAsset.transferAndCall(address(maliciousLiquidator));
    }

}
