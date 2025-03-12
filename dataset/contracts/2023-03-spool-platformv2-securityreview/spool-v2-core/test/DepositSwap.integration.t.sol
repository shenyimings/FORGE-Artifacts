// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/interfaces/RequestType.sol";
import "../src/DepositSwap.sol";
import "../src/SmartVaultFactory.sol";
import "../src/Swapper.sol";
import "./libraries/Arrays.sol";
import "./libraries/Constants.sol";
import "./mocks/MockExchange.sol";
import "./mocks/MockPriceFeedManager.sol";
import "./mocks/MockStrategy.sol";
import "./mocks/MockToken.sol";
import "./fixtures/TestFixture.sol";
import "./mocks/MockWeth.sol";

contract DepositSwapIntegrationTest is TestFixture {
    address private alice;
    address private bob;
    address swapperAdmin;

    MockToken private tokenA;
    MockToken private tokenB;
    MockToken private tokenC;

    IWETH9 private weth;

    DepositSwap depositSwap;

    function setUp() public {
        setUpBase();

        alice = address(0xa);
        bob = address(0xb);
        swapperAdmin = address(0xc);

        accessControl.grantRole(ROLE_SPOOL_ADMIN, swapperAdmin);

        tokenA = new MockToken("Token A", "TA");
        tokenB = new MockToken("Token B", "TB");
        tokenC = new MockToken("Token C", "TC");

        assetGroupRegistry.allowToken(address(tokenA));
        assetGroupRegistry.allowToken(address(tokenB));
        assetGroupRegistry.allowToken(address(tokenC));
        assetGroupRegistry.registerAssetGroup(Arrays.toArray(address(tokenA), address(tokenB), address(tokenC)));

        weth = IWETH9(address(new WETH9()));

        uint256 assetGroupId;
        {
            address[] memory assetGroup = new address[](2);
            assetGroup[0] = address(tokenA);
            assetGroup[1] = address(tokenB);
            assetGroupId = assetGroupRegistry.registerAssetGroup(assetGroup);
        }

        MockStrategy strategy = new MockStrategy("Strategy", assetGroupRegistry, accessControl, swapper);
        {
            uint256[] memory strategyRatios = new uint256[](2);
            strategyRatios[0] = 800;
            strategyRatios[1] = 200;
            strategy.initialize(assetGroupId, strategyRatios);
            strategyRegistry.registerStrategy(address(strategy));
        }

        {
            vm.mockCall(
                address(riskManager),
                abi.encodeWithSelector(IRiskManager.calculateAllocation.selector),
                abi.encode(Arrays.toUint16a16(1_000))
            );

            smartVault = smartVaultFactory.deploySmartVault(
                SmartVaultSpecification({
                    smartVaultName: "SmartVault",
                    assetGroupId: assetGroupId,
                    actions: new IAction[](0),
                    actionRequestTypes: new RequestType[](0),
                    guards: new GuardDefinition[][](0),
                    guardRequestTypes: new RequestType[](0),
                    strategies: Arrays.toArray(address(strategy)),
                    strategyAllocation: uint16a16.wrap(0),
                    riskTolerance: 4,
                    riskProvider: riskProvider,
                    managementFeePct: 0,
                    depositFeePct: 0,
                    allowRedeemFor: false,
                    allocationProvider: address(allocationProvider),
                    performanceFeePct: 0
                })
            );
        }
    }

    function test_depositSwap_swapAndDeposit_shouldDoCompleteSwapAndThenDeposit() public {
        tokenC.mint(alice, 2 ether);

        MockExchange exchangeAC = new MockExchange(tokenA, tokenC, priceFeedManager);
        tokenA.mint(address(exchangeAC), 1000 ether);
        tokenC.mint(address(exchangeAC), 1000 ether);
        MockExchange exchangeBC = new MockExchange(tokenB, tokenC, priceFeedManager);
        tokenB.mint(address(exchangeBC), 1000 ether);
        tokenC.mint(address(exchangeBC), 1000 ether);

        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(exchangeAC), address(exchangeBC)), Arrays.toArray(true, true)
        );
        vm.stopPrank();

        priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenC), 2 * USD_DECIMALS_MULTIPLIER);

        depositSwap = new DepositSwap(weth, assetGroupRegistry, smartVaultManager, swapper);

        SwapInfo[] memory swapInfo = new SwapInfo[](2);
        swapInfo[0] = SwapInfo(
            address(exchangeAC),
            address(tokenC),
            1 ether,
            abi.encodeWithSelector(exchangeAC.swap.selector, address(tokenC), 1 ether, address(depositSwap))
        );
        swapInfo[1] = SwapInfo(
            address(exchangeBC),
            address(tokenC),
            1 ether,
            abi.encodeWithSelector(exchangeBC.swap.selector, address(tokenC), 0.25 ether, address(depositSwap))
        );

        vm.startPrank(alice);
        tokenC.approve(address(depositSwap), 2 ether);

        uint256 nftId = depositSwap.swapAndDeposit(
            Arrays.toArray(address(tokenC)), Arrays.toArray(2 ether), swapInfo, address(smartVault), bob
        );
        vm.stopPrank();

        assertEq(nftId, 1, "NFT ID"); // deposit is made
        assertEq(tokenA.balanceOf(address(masterWallet)), 2 ether, "Token A - MasterWallet"); // swapped
        assertEq(tokenB.balanceOf(address(masterWallet)), 0.5 ether, "Token B - MasterWallet"); // swapped
        assertEq(tokenC.balanceOf(alice), 0.75 ether, "Token C - Alice"); // returned unswapped tokens

        DepositMetadata memory depositMetadata =
            abi.decode(smartVault.getMetadata(Arrays.toArray(nftId))[0], (DepositMetadata));

        assertEq(depositMetadata.assets.length, 2, "assets length"); // check deposit
        assertEq(depositMetadata.assets[0], 2 ether, "assets 0");
        assertEq(depositMetadata.assets[1], 0.5 ether, "assets 1");
        assertEq(smartVault.balanceOfFractional(bob, nftId), NFT_MINTED_SHARES, "NFT - Bob");
    }

    function test_depositSwap_swapAndDeposit_shouldDoPartialSwapAndThenDeposit() public {
        tokenA.mint(alice, 2 ether);

        MockExchange exchangeAB = new MockExchange(tokenA, tokenB, priceFeedManager);
        tokenA.mint(address(exchangeAB), 1000 ether);
        tokenB.mint(address(exchangeAB), 1000 ether);

        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(Arrays.toArray(address(exchangeAB)), Arrays.toArray(true));
        vm.stopPrank();

        priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);

        depositSwap = new DepositSwap(weth, assetGroupRegistry, smartVaultManager, swapper);

        SwapInfo[] memory swapInfo = new SwapInfo[](1);
        swapInfo[0] = SwapInfo(
            address(exchangeAB),
            address(tokenA),
            0.4 ether,
            abi.encodeWithSelector(exchangeAB.swap.selector, address(tokenA), 0.4 ether, address(depositSwap))
        );

        vm.startPrank(alice);
        tokenA.approve(address(depositSwap), 2 ether);

        uint256 nftId = depositSwap.swapAndDeposit(
            Arrays.toArray(address(tokenA)), Arrays.toArray(2 ether), swapInfo, address(smartVault), bob
        );
        vm.stopPrank();

        assertEq(nftId, 1, "NFT ID"); // deposit is made
        assertEq(tokenA.balanceOf(address(masterWallet)), 1.6 ether, "Token A - MasterWallet"); // swapped
        assertEq(tokenB.balanceOf(address(masterWallet)), 0.4 ether, "Token B - MasterWallet"); // swapped
        assertEq(tokenA.balanceOf(alice), 0 ether, "Token A - Alice");

        DepositMetadata memory depositMetadata =
            abi.decode(smartVault.getMetadata(Arrays.toArray(nftId))[0], (DepositMetadata));

        assertEq(depositMetadata.assets.length, 2, "assets length"); // check deposit
        assertEq(depositMetadata.assets[0], 1.6 ether, "assets 0");
        assertEq(depositMetadata.assets[1], 0.4 ether, "assets 1");
        assertEq(smartVault.balanceOfFractional(bob, nftId), NFT_MINTED_SHARES, "NFT - Bob");
    }

    function test_depositSwap_swapAndDeposit_shouldWrapEthSwapItAndThenDeposit() public {
        vm.deal(alice, 3 ether);
        vm.prank(alice);
        weth.deposit{value: 1 ether}(); // Alice wraps 1 ether

        MockExchange exchangeWethA = new MockExchange(IERC20(address(weth)), tokenA, priceFeedManager);
        tokenA.mint(address(exchangeWethA), 1000 ether);
        MockExchange exchangeWethB = new MockExchange(IERC20(address(weth)), tokenB, priceFeedManager);
        tokenB.mint(address(exchangeWethB), 1000 ether);

        vm.startPrank(swapperAdmin);
        swapper.updateExchangeAllowlist(
            Arrays.toArray(address(exchangeWethA), address(exchangeWethB)), Arrays.toArray(true, true)
        );
        vm.stopPrank();

        priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(weth), 1 * USD_DECIMALS_MULTIPLIER);

        depositSwap = new DepositSwap(weth, assetGroupRegistry, smartVaultManager, swapper);

        SwapInfo[] memory swapInfo = new SwapInfo[](2);
        swapInfo[0] = SwapInfo(
            address(exchangeWethA),
            address(weth),
            2 ether,
            abi.encodeWithSelector(exchangeWethA.swap.selector, address(weth), 2 ether, address(depositSwap))
        );
        swapInfo[1] = SwapInfo(
            address(exchangeWethB),
            address(weth),
            0.5 ether,
            abi.encodeWithSelector(exchangeWethB.swap.selector, address(weth), 0.5 ether, address(depositSwap))
        );

        vm.startPrank(alice);
        IERC20(address(weth)).approve(address(depositSwap), 1 ether);

        uint256 nftId = depositSwap.swapAndDeposit{value: 2 ether}(
            Arrays.toArray(address(weth)), Arrays.toArray(1 ether), swapInfo, address(smartVault), bob
        ); // Alice sends in 2 ether and 1 wrapped ether
        vm.stopPrank();

        assertEq(nftId, 1, "NFT ID"); // deposit is made
        assertEq(tokenA.balanceOf(address(masterWallet)), 2 ether, "Token A - MasterWallet"); // swapped
        assertEq(tokenB.balanceOf(address(masterWallet)), 0.5 ether, "Token B - MasterWallet"); // swapped
        assertEq(IERC20(address(weth)).balanceOf(alice), 0.5 ether, "WETH - Alice"); // unswapped

        DepositMetadata memory depositMetadata =
            abi.decode(smartVault.getMetadata(Arrays.toArray(nftId))[0], (DepositMetadata));

        assertEq(depositMetadata.assets.length, 2, "assets length"); // check deposit
        assertEq(depositMetadata.assets[0], 2 ether, "assets 0");
        assertEq(depositMetadata.assets[1], 0.5 ether, "assets 1");
        assertEq(smartVault.balanceOfFractional(bob, nftId), NFT_MINTED_SHARES, "NFT - Bob");
    }

    function test_depositSwap_swapAndDeposit_shouldWrapAndReturnItEvenWhenNotInInTokens() public {
        vm.deal(alice, 2 ether);
        tokenA.mint(alice, 2 ether);
        tokenB.mint(alice, 0.5 ether);

        priceFeedManager.setExchangeRate(address(tokenA), 1 * USD_DECIMALS_MULTIPLIER);
        priceFeedManager.setExchangeRate(address(tokenB), 1 * USD_DECIMALS_MULTIPLIER);

        depositSwap = new DepositSwap(weth, assetGroupRegistry, smartVaultManager, swapper);

        SwapInfo[] memory swapInfo = new SwapInfo[](0);

        vm.startPrank(alice);
        IERC20(address(tokenA)).approve(address(depositSwap), 2 ether);
        IERC20(address(tokenB)).approve(address(depositSwap), 0.5 ether);

        uint256 nftId = depositSwap.swapAndDeposit{value: 2 ether}(
            Arrays.toArray(address(tokenA), address(tokenB)),
            Arrays.toArray(2 ether, 0.5 ether),
            swapInfo,
            address(smartVault),
            bob
        ); // Alice sends in 2 ether but it is not used
        vm.stopPrank();

        assertEq(nftId, 1, "NFT ID"); // deposit is made
        assertEq(tokenA.balanceOf(address(masterWallet)), 2 ether, "Token A - MasterWallet"); // deposited
        assertEq(tokenB.balanceOf(address(masterWallet)), 0.5 ether, "Token B - MasterWallet"); // deposited
        assertEq(IERC20(address(weth)).balanceOf(alice), 2 ether, "WETH - Alice"); // returned
    }
}
