// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import "../../src/access/SpoolAccessControl.sol";
import "../../src/managers/ActionManager.sol";
import "../../src/managers/AssetGroupRegistry.sol";
import "../../src/managers/DepositManager.sol";
import "../../src/managers/GuardManager.sol";
import "../../src/managers/RiskManager.sol";
import "../../src/managers/SmartVaultManager.sol";
import "../../src/managers/StrategyRegistry.sol";
import "../../src/managers/UsdPriceFeedManager.sol";
import "../../src/managers/WithdrawalManager.sol";
import "../../src/strategies/GhostStrategy.sol";
import "../../src/MasterWallet.sol";
import "../../src/SmartVault.sol";
import "../../src/SmartVaultFactory.sol";
import "../../src/Swapper.sol";
import "../libraries/Arrays.sol";
import "../libraries/Constants.sol";
import "../mocks/MockExchange.sol";
import "../mocks/MockPriceFeedManager.sol";
import "../mocks/MockStrategy.sol";
import "../mocks/MockToken.sol";

contract ReallocationIntegrationTest is Test {
    address private alice;
    address private bob;

    address private reallocator;
    address private doHardWorker;
    address private riskProvider;

    MockToken private tokenA;
    MockToken private tokenB;

    SmartVaultManager private smartVaultManager;
    StrategyRegistry private strategyRegistry;
    MasterWallet private masterWallet;
    AssetGroupRegistry private assetGroupRegistry;
    SpoolAccessControl private accessControl;
    IRiskManager private riskManager;
    MockPriceFeedManager private priceFeedManager;
    Swapper private swapper;
    SmartVaultFactory private smartVaultFactory;

    function setUp() public {
        alice = address(0xa);
        bob = address(0xb);

        tokenA = new MockToken("Token A", "TA");
        tokenB = new MockToken("Token B", "TB");

        accessControl = new SpoolAccessControl();
        accessControl.initialize();

        reallocator = address(0x1);
        accessControl.grantRole(ROLE_REALLOCATOR, reallocator);
        riskProvider = address(0x2);
        IStrategy ghostStrategy = new GhostStrategy();
        doHardWorker = address(0x3);
        accessControl.grantRole(ROLE_DO_HARD_WORKER, doHardWorker);

        accessControl.grantRole(ROLE_RISK_PROVIDER, riskProvider);

        masterWallet = new MasterWallet(accessControl);

        assetGroupRegistry = new AssetGroupRegistry(accessControl);
        assetGroupRegistry.initialize(Arrays.toArray(address(tokenA), address(tokenB)));

        priceFeedManager = new MockPriceFeedManager();

        strategyRegistry = new StrategyRegistry(masterWallet, accessControl, priceFeedManager, address(ghostStrategy));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(strategyRegistry));
        accessControl.grantRole(ROLE_STRATEGY_REGISTRY, address(strategyRegistry));
        accessControl.grantRole(ADMIN_ROLE_STRATEGY, address(strategyRegistry));

        IActionManager actionManager = new ActionManager(accessControl);
        IGuardManager guardManager = new GuardManager(accessControl);

        riskManager = new RiskManager(accessControl, strategyRegistry, address(ghostStrategy));

        swapper = new Swapper(accessControl);

        DepositManager depositManager =
            new DepositManager(strategyRegistry, priceFeedManager, guardManager, actionManager, accessControl);
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(depositManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(depositManager));

        WithdrawalManager withdrawalManager =
        new WithdrawalManager(strategyRegistry, priceFeedManager, masterWallet, guardManager, actionManager, accessControl);
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(withdrawalManager));
        accessControl.grantRole(ROLE_ALLOCATION_PROVIDER, address(0xabc));

        smartVaultManager = new SmartVaultManager(
            accessControl,
            assetGroupRegistry,
            riskManager,
            depositManager,
            withdrawalManager,
            strategyRegistry,
            masterWallet,
            priceFeedManager,
            address(ghostStrategy)
        );
        accessControl.grantRole(ROLE_SMART_VAULT_MANAGER, address(smartVaultManager));
        accessControl.grantRole(ROLE_MASTER_WALLET_MANAGER, address(smartVaultManager));

        address smartVaultImplementation = address(new SmartVault(accessControl, guardManager));
        smartVaultFactory = new SmartVaultFactory(
            smartVaultImplementation,
            accessControl,
            actionManager,
            guardManager,
            smartVaultManager,
            assetGroupRegistry,
            riskManager
        );

        accessControl.grantRole(ROLE_SMART_VAULT_INTEGRATOR, address(smartVaultFactory));

        deal(address(tokenA), alice, 1000 ether, true);
        deal(address(tokenB), alice, 1000 ether, true);
        deal(address(tokenA), bob, 1000 ether, true);
        deal(address(tokenB), bob, 1000 ether, true);
    }

    function generateDhwParameterBag(address[] memory strategies, address[] memory assetGroup)
        private
        view
        returns (DoHardWorkParameterBag memory)
    {
        address[][] memory strategyGroups = new address[][](1);
        strategyGroups[0] = strategies;

        SwapInfo[][][] memory swapInfo = new SwapInfo[][][](1);
        swapInfo[0] = new SwapInfo[][](strategies.length);
        SwapInfo[][][] memory compoundSwapInfo = new SwapInfo[][][](1);
        compoundSwapInfo[0] = new SwapInfo[][](strategies.length);

        uint256[][][] memory strategySlippages = new uint256[][][](1);
        strategySlippages[0] = new uint256[][](strategies.length);

        for (uint256 i; i < strategies.length; ++i) {
            swapInfo[0][i] = new SwapInfo[](0);
            compoundSwapInfo[0][i] = new SwapInfo[](0);
            strategySlippages[0][i] = new uint256[](0);
        }

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](assetGroup.length);

        for (uint256 i; i < assetGroup.length; ++i) {
            exchangeRateSlippages[i][0] = priceFeedManager.exchangeRates(assetGroup[i]);
            exchangeRateSlippages[i][1] = priceFeedManager.exchangeRates(assetGroup[i]);
        }

        int256[][] memory baseYields = new int256[][](1);
        baseYields[0] = new int256[](strategies.length);

        return DoHardWorkParameterBag({
            strategies: strategyGroups,
            swapInfo: swapInfo,
            compoundSwapInfo: compoundSwapInfo,
            strategySlippages: strategySlippages,
            tokens: assetGroup,
            exchangeRateSlippages: exchangeRateSlippages,
            baseYields: baseYields
        });
    }

    function generateReallocateParamBag(
        address[] memory smartVaults,
        address[] memory strategies,
        address[] memory assetGroup
    ) private view returns (ReallocateParamBag memory) {
        SwapInfo[][] memory reallocationSwapInfo = new SwapInfo[][](strategies.length);
        uint256[][] memory depositSlippages = new uint256[][](strategies.length);
        uint256[][] memory withdrawalSlippages = new uint256[][](strategies.length);

        for (uint256 i; i < strategies.length; ++i) {
            reallocationSwapInfo[i] = new SwapInfo[](0);

            depositSlippages[i] = new uint256[](0);
            withdrawalSlippages[i] = new uint256[](0);
        }

        uint256[2][] memory exchangeRateSlippages = new uint256[2][](assetGroup.length);
        for (uint256 i; i < assetGroup.length; ++i) {
            exchangeRateSlippages[i][0] = priceFeedManager.exchangeRates(assetGroup[i]);
            exchangeRateSlippages[i][1] = priceFeedManager.exchangeRates(assetGroup[i]);
        }

        return ReallocateParamBag({
            smartVaults: smartVaults,
            strategies: strategies,
            swapInfo: reallocationSwapInfo,
            depositSlippages: depositSlippages,
            withdrawalSlippages: withdrawalSlippages,
            exchangeRateSlippages: exchangeRateSlippages
        });
    }

    function _getSmartVaultSpecification() private view returns (SmartVaultSpecification memory) {
        return SmartVaultSpecification({
            smartVaultName: "",
            assetGroupId: 0,
            actions: new IAction[](0),
            actionRequestTypes: new RequestType[](0),
            guards: new GuardDefinition[][](0),
            guardRequestTypes: new RequestType[](0),
            strategies: new address[](0),
            strategyAllocation: uint16a16.wrap(0),
            riskTolerance: 4,
            riskProvider: riskProvider,
            allocationProvider: address(0xabc),
            managementFeePct: 0,
            depositFeePct: 0,
            performanceFeePct: 0,
            allowRedeemFor: false
        });
    }

    function test_reallocate_01() public {
        // setup:
        // - tokens: A
        // - smart vaults: A
        //   - strategies: A, B
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 10
        //   - strategy B: deposit 10
        // [[ 0, 10]
        //  [ 0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vault
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 100 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultA),
                    assets: Arrays.toArray(100 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 60 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 40 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 60_000000000000000000000);
        assertEq(strategyB.totalSupply(), 40_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 40_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(50_00, 50_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA)),
                Arrays.toArray(address(strategyA), address(strategyB)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault A"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 50 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 50_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 50_000000000000000000000, "final SSTB supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTB balance smartVaultA");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
    }

    function test_reallocate_02() public {
        // setup:
        // - tokens: A
        // - smart vaults: A
        //   - strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 10
        //   - strategy B: withdraw 5
        //   - strategy C: deposit 15
        // [[ 0,  0, 10]
        //  [ 0,  0,  5]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vault
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(50_00, 35_00, 15_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 100 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultA),
                    assets: Arrays.toArray(100 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 35 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 15 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 50_000000000000000000000);
        assertEq(strategyB.totalSupply(), 35_000000000000000000000);
        assertEq(strategyC.totalSupply(), 15_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 15_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate, invalid strategy array length
        vm.startPrank(reallocator);
        ReallocateParamBag memory bag = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        bag.strategies = Arrays.toArray(address(strategyA), address(strategyB));
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        smartVaultManager.reallocate(bag);
        vm.stopPrank();

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 40 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 40_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 30_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 30_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
    }

    function test_reallocate_03() public {
        // setup:
        // - tokens: A
        // - smart vaults: A
        //   - strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 15
        //   - strategy B: deposit 5
        //   - strategy C: deposit 10
        // [[ 0,  5, 10]
        //  [ 0,  0,  0]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vault
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(55_00, 25_00, 20_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 100 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultA),
                    assets: Arrays.toArray(100 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 55 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 25 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 20 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 55_000000000000000000000);
        assertEq(strategyB.totalSupply(), 25_000000000000000000000);
        assertEq(strategyC.totalSupply(), 20_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 55_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 25_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 20_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 40 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 40_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 30_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 30_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
    }

    function test_reallocate_04() public {
        // setup:
        // - tokens: A
        // - smart vaults: A
        //   - strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 10
        //   - strategy B: /
        //   - strategy C: deposit 10
        // [[ 0,  0, 10]
        //  [ 0,  0,  0]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vault
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(50_00, 30_00, 20_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 100 ether);
            uint256 depositNft = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultA),
                    assets: Arrays.toArray(100 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNft), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 20 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 50_000000000000000000000);
        assertEq(strategyB.totalSupply(), 30_000000000000000000000);
        assertEq(strategyC.totalSupply(), 20_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 20_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 40 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 30 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 40_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 30_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 30_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
    }

    function test_reallocate_05() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B
        //   - B strategies: B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 10
        //   - strategy B: deposit 10
        // - smart vault B
        //   - strategy B: withdraw 15
        //   - strategy C: deposit 15
        // [[ 0, 10,  0]
        //  [ 0,  0, 15]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(65_00, 35_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 60 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 105 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 35 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 60_000000000000000000000);
        assertEq(strategyB.totalSupply(), 105_000000000000000000000);
        assertEq(strategyC.totalSupply(), 35_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 40_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 65_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 35_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(50_00, 50_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 100 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 50 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 50_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 100_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 50_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_06() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B
        //   - B strategies: B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 15
        //   - strategy B: deposit 15
        // - smart vault B
        //   - strategy B: withdraw 10
        //   - strategy C: deposit 10
        // [[ 0, 15,  0]
        //  [ 0,  0, 10]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(65_00, 35_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 95 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 40 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 65_000000000000000000000);
        assertEq(strategyB.totalSupply(), 95_000000000000000000000);
        assertEq(strategyC.totalSupply(), 40_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 65_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 35_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 60_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(50_00, 50_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 100 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 50 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 50_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 100_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 50_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_07() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B
        //   - B strategies: B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 10
        //   - strategy B: deposit 10
        // - smart vault B
        //   - strategy B: withdraw 10
        //   - strategy C: deposit 10
        // [[ 0, 10,  0]
        //  [ 0,  0, 10]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 60 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 100 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 40 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 60_000000000000000000000);
        assertEq(strategyB.totalSupply(), 100_000000000000000000000);
        assertEq(strategyC.totalSupply(), 40_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 40_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 60_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(50_00, 50_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 50 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 100 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 50 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 50_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 100_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 50_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_08() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 20
        //   - strategy B: deposit 15
        //   - strategy C: deposit 5
        // - smart vault B
        //   - strategy A: withdraw 15
        //   - strategy B: deposit 10
        //   - strategy C: deposit 5
        // [[ 0, 25, 10]
        //  [ 0,  0,  0]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 15_00, 25_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(55_00, 20_00, 25_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 115 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 35 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 50 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 115_000000000000000000000);
        assertEq(strategyB.totalSupply(), 35_000000000000000000000);
        assertEq(strategyC.totalSupply(), 50_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 15_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 25_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 55_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 20_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 25_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 60_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_09() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 20
        //   - strategy B: deposit 15
        //   - strategy C: deposit 5
        // - smart vault B
        //   - strategy A: deposit 20
        //   - strategy B: withdraw 15
        //   - strategy C: withdraw 5
        // [[ 0, 15,  5]
        //  [15,  0,  0]
        //  [ 5,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 15_00, 25_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(20_00, 45_00, 35_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 80_000000000000000000000);
        assertEq(strategyB.totalSupply(), 60_000000000000000000000);
        assertEq(strategyC.totalSupply(), 60_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 15_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 25_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 20_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 45_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 35_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 60_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_10() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 20
        //   - strategy B: deposit 15
        //   - strategy C: deposit 5
        // - smart vault B
        //   - strategy A: deposit 15
        //   - strategy B: withdraw 5
        //   - strategy C: withdraw 10
        // [[ 0, 15,  5]
        //  [ 5,  0,  0]
        //  [10,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 15_00, 25_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(25_00, 35_00, 40_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 85 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 50 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 85_000000000000000000000);
        assertEq(strategyB.totalSupply(), 50_000000000000000000000);
        assertEq(strategyC.totalSupply(), 65_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 15_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 25_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 25_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 60_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_11() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 30
        //   - strategy B: deposit 10
        //   - strategy C: deposit 20
        // - smart vault B
        //   - strategy A: deposit 15
        //   - strategy B: withdraw 5
        //   - strategy C: withdraw 10
        // [[ 0, 10, 20]
        //  [ 5,  0,  0]
        //  [10,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(70_00, 20_00, 10_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(25_00, 35_00, 40_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 95 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 55 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 50 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 95_000000000000000000000);
        assertEq(strategyB.totalSupply(), 55_000000000000000000000);
        assertEq(strategyC.totalSupply(), 50_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 70_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 20_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 10_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 25_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 60_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_12() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 15
        //   - strategy B: deposit 5
        //   - strategy C: deposit 10
        // - smart vault B
        //   - strategy A: deposit 30
        //   - strategy B: withdraw 10
        //   - strategy C: withdraw 20
        // [[ 0,  5, 10]
        //  [10,  0,  0]
        //  [20,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(55_00, 25_00, 20_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(10_00, 40_00, 50_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 70 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 65_000000000000000000000);
        assertEq(strategyB.totalSupply(), 65_000000000000000000000);
        assertEq(strategyC.totalSupply(), 70_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 55_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 25_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 20_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 10_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 50_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 60 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 60_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_13() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // - strategy A has withdrawal fee of 20%
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 25
        //   - strategy B: deposit 10 (-> 8)
        //   - strategy C: deposit 15 (-> 12)
        // - smart vault B
        //   - strategy A: /
        //   - strategy B: withdraw 5
        //   - strategy C: deposit 5
        // [[ 0, 10, 15]
        //  [ 0,  0,  5]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));
            strategyA.setWithdrawalFee(20_00);

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(65_00, 20_00, 15_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(40_00, 35_00, 25_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 105 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 55 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 40 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 105_000000000000000000000);
        assertEq(strategyB.totalSupply(), 55_000000000000000000000);
        assertEq(strategyC.totalSupply(), 40_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 65_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 20_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 15_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 25_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 58 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 57 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(strategyA.protocolFees())), 5 ether, "final tokenA strategyA fees");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 58_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 57_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 28_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 27_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_14() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // - strategy A has withdrawal fee of 20%
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 15
        //   - strategy B: withdraw 5
        //   - strategy C: deposit 20 (-> 18)
        // - smart vault B
        //   - strategy A: withdraw 10
        //   - strategy B: /
        //   - strategy C: deposit 10 (-> 8)
        // [[ 0,  0, 25]
        //  [ 0,  0,  5]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));
            strategyA.setWithdrawalFee(20_00);

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(55_00, 35_00, 10_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(50_00, 30_00, 20_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 105 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 30 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 105_000000000000000000000);
        assertEq(strategyB.totalSupply(), 65_000000000000000000000);
        assertEq(strategyC.totalSupply(), 30_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 55_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 10_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 50_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 20_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 55 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(strategyA.protocolFees())), 5 ether, "final tokenA strategyA fees");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 55_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 27_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 28_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_15() public {
        // setup:
        // - tokens: A
        // - smart vaults: A, B
        //   - A strategies: A, B, C
        //   - B strategies: A, B, C
        // - strategy C has deposit fee of 20% (only for reallocation)
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw 15
        //   - strategy B: withdraw 5
        //   - strategy C: deposit 20 (-> 16)
        // - smart vault B
        //   - strategy A: withdraw 10
        //   - strategy B: /
        //   - strategy C: deposit 10 (-> 8)
        // [[ 0,  0, 25]
        //  [ 0,  0, 10]
        //  [ 0,  0,  0]]

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(55_00, 35_00, 10_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB), address(strategyC));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(50_00, 30_00, 20_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 100 TokenA into SmartVaultA and SmartVaultB
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 200 ether);
            DepositBag memory bag = DepositBag({
                smartVault: address(smartVaultA),
                assets: Arrays.toArray(100 ether),
                receiver: alice,
                referral: address(0),
                doFlush: false
            });
            uint256 depositNftA = smartVaultManager.deposit(bag);

            bag.smartVault = address(smartVaultB);
            uint256 depositNftB = smartVaultManager.deposit(bag);
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftA), Arrays.toArray(NFT_MINTED_SHARES)
            );
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftB), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("strategy C", address(strategyC));

        // check initial state
        // - assets were routed to strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 105 ether);
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 65 ether);
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 30 ether);
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
        // - strategy tokens were minted
        assertEq(strategyA.totalSupply(), 105_000000000000000000000);
        assertEq(strategyB.totalSupply(), 65_000000000000000000000);
        assertEq(strategyC.totalSupply(), 30_000000000000000000000);
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 55_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultA)), 35_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultA)), 10_000000000000000000000);
        assertEq(strategyA.balanceOf(address(smartVaultB)), 50_000000000000000000000);
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000);
        assertEq(strategyC.balanceOf(address(smartVaultB)), 20_000000000000000000000);
        // - smart vault tokens were minted
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
        // - smart vault tokens were distributed
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000);

        // set deposit fee for strategy C
        strategyC.setDepositFee(20_00);

        // mock changes in allocation
        vm.mockCall(
            address(riskManager),
            abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
            abi.encode(Arrays.toUint16a16(40_00, 30_00, 30_00))
        );

        // reallocate
        vm.startPrank(reallocator);
        smartVaultManager.reallocate(
            generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            )
        );
        vm.stopPrank();

        // check final state
        // - new allocation was set
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault A"
        );
        assertEq(
            uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
            uint16a16.unwrap(Arrays.toUint16a16(40_00, 30_00, 30_00)),
            "final allocation for smart vault B"
        );
        // - assets were redistributed between strategies
        assertEq(tokenA.balanceOf(address(strategyA.protocol())), 80 ether, "final tokenA balance strategyA");
        assertEq(tokenA.balanceOf(address(strategyB.protocol())), 60 ether, "final tokenA balance strategyB");
        assertEq(tokenA.balanceOf(address(strategyC.protocol())), 54 ether, "final tokenA balance strategyC");
        assertEq(tokenA.balanceOf(address(strategyC.protocolFees())), 6 ether, "final tokenA strategyC fees");
        assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
        // - strategy tokens were minted and burned
        assertEq(strategyA.totalSupply(), 80_000000000000000000000, "final SSTA supply");
        assertEq(strategyB.totalSupply(), 60_000000000000000000000, "final SSTB supply");
        assertEq(strategyC.totalSupply(), 54_000000000000000000000, "final SSTC supply");
        // - strategy tokens were distributed
        assertEq(strategyA.balanceOf(address(smartVaultA)), 40_000000000000000000000, "final SSTA balance smartVaultA");
        assertEq(strategyB.balanceOf(address(smartVaultA)), 30_000000000000000000000, "final SSTB balance smartVaultA");
        assertEq(strategyC.balanceOf(address(smartVaultA)), 26_000000000000000000000, "final SSTC balance smartVaultA");
        assertEq(strategyA.balanceOf(address(smartVaultB)), 40_000000000000000000000, "final SSTA balance smartVaultB");
        assertEq(strategyB.balanceOf(address(smartVaultB)), 30_000000000000000000000, "final SSTB balance smartVaultB");
        assertEq(strategyC.balanceOf(address(smartVaultB)), 28_000000000000000000000, "final SSTC balance smartVaultB");
        // - smart vault tokens remain unchanged
        assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
        assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
        // - smart vault tokens distribution remains unchanged
        assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
        assertEq(smartVaultB.balanceOf(alice), 100_000000000000000000000, "final SVTB balance alice");
    }

    function test_reallocate_multiasset() public {
        // setup:
        // - tokens: A, B
        // - smart vaults: A, B
        //   - A strategies: A, B
        //   - B strategies: A, B
        // reallocation
        // - smart vault A
        //   - strategy A: withdraw
        //   - strategy B: deposit
        // - smart vault B
        //   - strategy A: deposit
        //   - strategy B: withdraw

        // setup assets group with TokenA and TokenB
        uint256 assetGroupId;
        MockExchange exchangeAB;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenB), address(tokenA)));

            // ASSET GROUP IS [TOKENB, TOKENA]!!!!

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
            priceFeedManager.setExchangeRate(address(tokenB), 2 * USD_DECIMALS_MULTIPLIER);

            // create exchange for tokenA <-> tokenB
            exchangeAB = new MockExchange(tokenA, tokenB, priceFeedManager);
            tokenA.mint(address(exchangeAB), 1000 ether);
            tokenB.mint(address(exchangeAB), 1000 ether);
            swapper.updateExchangeAllowlist(Arrays.toArray(address(exchangeAB)), Arrays.toArray(true));
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(10, 20));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(9, 22));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(20_00, 80_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // setup initial state
        {
            // Alice deposits 52 TokenA and 24 TokenB into SmartVaultA
            vm.startPrank(alice);
            tokenA.approve(address(smartVaultManager), 52 ether);
            tokenB.approve(address(smartVaultManager), 24 ether);
            uint256 depositNftAlice = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultA),
                    assets: Arrays.toArray(24 ether, 52 ether),
                    receiver: alice,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // Bob deposits 54 TokenA and 23 TokenB into SmartVaultB
            vm.startPrank(bob);
            tokenA.approve(address(smartVaultManager), 54 ether);
            tokenB.approve(address(smartVaultManager), 23 ether);
            uint256 depositNftBob = smartVaultManager.deposit(
                DepositBag({
                    smartVault: address(smartVaultB),
                    assets: Arrays.toArray(23 ether, 54 ether),
                    receiver: bob,
                    referral: address(0),
                    doFlush: false
                })
            );
            vm.stopPrank();

            // flush, DHW, sync
            smartVaultManager.flushSmartVault(address(smartVaultA));
            smartVaultManager.flushSmartVault(address(smartVaultB));

            vm.startPrank(doHardWorker);
            strategyRegistry.doHardWork(
                generateDhwParameterBag(
                    Arrays.toArray(address(strategyA), address(strategyB)),
                    assetGroupRegistry.listAssetGroup(assetGroupId)
                )
            );
            vm.stopPrank();

            smartVaultManager.syncSmartVault(address(smartVaultA), true);
            smartVaultManager.syncSmartVault(address(smartVaultB), true);

            // claim SVTs
            vm.startPrank(alice);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultA), Arrays.toArray(depositNftAlice), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();

            vm.startPrank(bob);
            smartVaultManager.claimSmartVaultTokens(
                address(smartVaultB), Arrays.toArray(depositNftBob), Arrays.toArray(NFT_MINTED_SHARES)
            );
            vm.stopPrank();
        }

        console.log("token A", address(tokenA));
        console.log("token B", address(tokenB));
        console.log("strategy A", address(strategyA));
        console.log("strategy B", address(strategyB));
        console.log("smart vault A", address(smartVaultA));
        console.log("smart vault B", address(smartVaultB));

        // check initial state
        {
            // - assets were routed to strategies
            assertEq(tokenA.balanceOf(address(strategyA.protocol())), 40 ether);
            assertEq(tokenB.balanceOf(address(strategyA.protocol())), 20 ether);
            assertEq(tokenA.balanceOf(address(strategyB.protocol())), 66 ether);
            assertEq(tokenB.balanceOf(address(strategyB.protocol())), 27 ether);
            assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether);
            assertEq(tokenB.balanceOf(address(masterWallet)), 0 ether);
            // - strategy tokens were minted
            assertEq(strategyA.totalSupply(), 80_000000000000000000000);
            assertEq(strategyB.totalSupply(), 120_000000000000000000000);
            // - strategy tokens were distributed
            assertEq(strategyA.balanceOf(address(smartVaultA)), 60_000000000000000000000);
            assertEq(strategyB.balanceOf(address(smartVaultA)), 40_000000000000000000000);
            assertEq(strategyA.balanceOf(address(smartVaultB)), 20_000000000000000000000);
            assertEq(strategyB.balanceOf(address(smartVaultB)), 80_000000000000000000000);
            // - smart vault tokens were minted
            assertEq(smartVaultA.totalSupply(), 100_000000000000000000000);
            assertEq(smartVaultB.totalSupply(), 100_000000000000000000000);
            // - smart vault tokens were distributed
            assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000);
            assertEq(smartVaultB.balanceOf(bob), 100_000000000000000000000);
        }

        // change settings
        {
            // set fees on strategies
            strategyA.setDepositFee(10_00);
            strategyB.setWithdrawalFee(20_00);

            // mock changes in allocation
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(50_00, 50_00))
            );
        }

        // reallocate
        {
            // smartVaultA should withdraw $10 worth from strategyA and deposit into strategyB
            // smartVaultB should withdraw $30 worth from strategyB and deposit into strategyA
            // $10 worth should get matched
            // $20 worth should get withdrawn from strategyB and deposited into strategyA
            //   - 11 tokenA and 4.5 tokenB
            // strategyB has 20% withdrawal fee
            //   - 2.2 tokenA and 0.9 tokenB taken as fees
            //   - 8.8 tokenA and 3.6 tokenB withdrawn
            // strategyA requires 20 : 10 deposit ratio
            //   - 8 tokenA and 4 tokenB required
            //   - swap 0.8 tokenA for 0.4 tokenB
            // strategyA has 10% deposit fee
            //   - 0.8 tokenA and 0.4 tokenB taken as fees
            //   - 7.2 tokenA and 3.6 tokenB deposited
            // these fees will only affect smartVaultB, since smartVaultA was totally matched

            vm.startPrank(reallocator);
            ReallocateParamBag memory paramBag = generateReallocateParamBag(
                Arrays.toArray(address(smartVaultA), address(smartVaultB)),
                Arrays.toArray(address(strategyA), address(strategyB)),
                assetGroupRegistry.listAssetGroup(assetGroupId)
            );

            paramBag.swapInfo[0] = new SwapInfo[](1);
            paramBag.swapInfo[0][0] = SwapInfo({
                swapTarget: address(exchangeAB),
                token: address(tokenA),
                amountIn: 0.8 ether,
                swapCallData: abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 0.8 ether, address(swapper))
            });

            smartVaultManager.reallocate(paramBag);
            vm.stopPrank();
        }

        // check final state
        {
            // - new allocation was set
            assertEq(
                uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultA))),
                uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
                "final allocation for smartVaultA"
            );
            assertEq(
                uint16a16.unwrap(smartVaultManager.allocations(address(smartVaultB))),
                uint16a16.unwrap(Arrays.toUint16a16(50_00, 50_00)),
                "final allocation for smartVaultB"
            );
            // - assets were redistributed between strategies
            assertEq(tokenA.balanceOf(address(strategyA.protocol())), 47.2 ether, "final tokenA balance strategyA");
            assertEq(tokenB.balanceOf(address(strategyA.protocol())), 23.6 ether, "final tokenA balance strategyA");
            assertEq(tokenA.balanceOf(address(strategyB.protocol())), 55 ether, "final tokenA balance strategyB");
            assertEq(tokenB.balanceOf(address(strategyB.protocol())), 22.5 ether, "final tokenA balance strategyB");
            assertEq(tokenA.balanceOf(address(strategyA.protocolFees())), 0.8 ether, "final tokenA strategyA fees");
            assertEq(tokenB.balanceOf(address(strategyA.protocolFees())), 0.4 ether, "final tokenB strategyA fees");
            assertEq(tokenA.balanceOf(address(strategyB.protocolFees())), 2.2 ether, "final tokenA strategyB fees");
            assertEq(tokenB.balanceOf(address(strategyB.protocolFees())), 0.9 ether, "final tokenB strategyB fees");
            assertEq(tokenA.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
            assertEq(tokenB.balanceOf(address(masterWallet)), 0 ether, "final tokenA balance masterWallet");
            // - strategy tokens were minted and burned
            assertEq(strategyA.totalSupply(), 94_400000000000000000000, "final SSTA supply");
            assertEq(strategyB.totalSupply(), 100_000000000000000000000, "final SSTB supply");
            // - strategy tokens were distributed
            assertEq(
                strategyA.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTA balance smartVaultA"
            );
            assertEq(
                strategyB.balanceOf(address(smartVaultA)), 50_000000000000000000000, "final SSTB balance smartVaultA"
            );
            assertEq(
                strategyA.balanceOf(address(smartVaultB)), 44_400000000000000000000, "final SSTA balance smartVaultB"
            );
            assertEq(
                strategyB.balanceOf(address(smartVaultB)), 50_000000000000000000000, "final SSTB balance smartVaultB"
            );
            // - smart vault tokens remain unchanged
            assertEq(smartVaultA.totalSupply(), 100_000000000000000000000, "final SVTA supply");
            assertEq(smartVaultB.totalSupply(), 100_000000000000000000000, "final SVTB supply");
            // - smart vault tokens distribution remains unchanged
            assertEq(smartVaultA.balanceOf(alice), 100_000000000000000000000, "final SVTA balance alice");
            assertEq(smartVaultB.balanceOf(bob), 100_000000000000000000000, "final SVTB balance bob");
        }
    }

    function test_reallocate_shouldRevertWhenNotCalledByReallocator() public {
        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // reallocate
        vm.startPrank(alice);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA), address(strategyB)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(abi.encodeWithSelector(MissingRole.selector, ROLE_REALLOCATOR, alice));
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }

    function test_reallocate_shouldRevertWhenSystemIsPaused() public {
        address pauser = address(0x9);
        accessControl.grantRole(ROLE_PAUSER, pauser);

        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        vm.prank(pauser);
        accessControl.pause();

        // reallocate
        vm.startPrank(reallocator);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA), address(strategyB)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(SystemPaused.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }

    function test_reallocate_shouldRevertWhenOneOfSmartVaultsIsNotRegistered() public {
        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            smartVaultB = ISmartVault(address(0x9));
        }

        // reallocate
        vm.startPrank(reallocator);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA), address(smartVaultB)),
            Arrays.toArray(address(strategyA), address(strategyB)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(SmartVaultNotRegisteredYet.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }

    function test_reallocate_shouldRevertWhenStrategiesAreNotSetOfSmartVaultStrategies() public {
        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        MockStrategy strategyC;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));

            strategyC = new MockStrategy("StratC", assetGroupRegistry, accessControl, swapper);
            strategyC.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyC));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(60_00, 40_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // reallocate
        vm.startPrank(reallocator);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA), address(strategyB), address(strategyC)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(InvalidStrategies.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();

        vm.startPrank(reallocator);
        reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(InvalidStrategies.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }

    function test_reallocate_shouldRevertWhenNotAllSmartVaultsHaveSameAssetGroup() public {
        // setup asset group with TokenA
        uint256 assetGroupId1;
        uint256 assetGroupId2;
        {
            assetGroupId1 = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));
            assetGroupId2 = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenB)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
            priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId1, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId2, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        ISmartVault smartVaultB;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId1;
            specification.strategies = Arrays.toArray(address(strategyA));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(100_00))
            );
            smartVaultA = smartVaultFactory.deploySmartVault(specification);

            specification.smartVaultName = "SmartVaultB";
            specification.assetGroupId = assetGroupId2;
            specification.strategies = Arrays.toArray(address(strategyB));
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(100_00))
            );
            smartVaultB = smartVaultFactory.deploySmartVault(specification);
        }

        // reallocate
        vm.startPrank(reallocator);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA), address(smartVaultB)),
            Arrays.toArray(address(strategyA), address(strategyB)),
            assetGroupRegistry.listAssetGroup(assetGroupId1)
        );
        vm.expectRevert(NotSameAssetGroup.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }

    function test_reallocate_shouldRevertWhenAnySmartVaultHasStaticallySetAllocation() public {
        // setup asset group with TokenA
        uint256 assetGroupId;
        {
            assetGroupId = assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA)));

            priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        }

        // setup strategies
        MockStrategy strategyA;
        MockStrategy strategyB;
        {
            strategyA = new MockStrategy("StratA", assetGroupRegistry, accessControl, swapper);
            strategyA.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyA));

            strategyB = new MockStrategy("StratB", assetGroupRegistry, accessControl, swapper);
            strategyB.initialize(assetGroupId, Arrays.toArray(1));
            strategyRegistry.registerStrategy(address(strategyB));
        }

        // setup smart vaults
        ISmartVault smartVaultA;
        {
            SmartVaultSpecification memory specification = _getSmartVaultSpecification();
            specification.smartVaultName = "SmartVaultA";
            specification.assetGroupId = assetGroupId;
            specification.strategyAllocation = Arrays.toUint16a16(60_00, 40_00);
            specification.strategies = Arrays.toArray(address(strategyA), address(strategyB));
            smartVaultA = smartVaultFactory.deploySmartVault(specification);
        }

        // reallocate
        vm.startPrank(reallocator);
        ReallocateParamBag memory reallocationParams = generateReallocateParamBag(
            Arrays.toArray(address(smartVaultA)),
            Arrays.toArray(address(strategyA), address(strategyB)),
            assetGroupRegistry.listAssetGroup(assetGroupId)
        );
        vm.expectRevert(StaticAllocationSmartVault.selector);
        smartVaultManager.reallocate(reallocationParams);
        vm.stopPrank();
    }
}
