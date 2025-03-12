// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeCast160} from "@permit2/libraries/SafeCast160.sol";
import {Permit2Lib} from "@permit2/libraries/Permit2Lib.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {BulkerGateway} from "src/extensions/BulkerGateway.sol";
import {IBulkerGateway} from "src/interfaces/extensions/IBulkerGateway.sol";
import {ILido} from "src/interfaces/extensions/ILido.sol";
import {IWSTETH} from "src/interfaces/extensions/IWSTETH.sol";

import {SigUtils} from "test/helpers/SigUtils.sol";

import {RewardsManagerMock} from "test/mocks/RewardsManagerMock.sol";

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationBulkerGateway is IntegrationTest {
    using SafeTransferLib for ERC20;
    using TestMarketLib for TestMarket;

    SigUtils internal sigUtils;
    IBulkerGateway internal bulker;

    address stETH;
    address wstETH;

    event Accrued(
        address indexed asset, address indexed reward, address indexed user, uint256 assetIndex, uint256 rewardsAccrued
    );

    function setUp() public virtual override {
        super.setUp();
        bulker = new BulkerGateway(address(morpho));
        sigUtils = new SigUtils(morpho.DOMAIN_SEPARATOR());
        stETH = bulker.stETH();
        wstETH = bulker.wstETH();
    }

    function _assumeTarget(address onBehalf) internal view {
        vm.assume(onBehalf != address(0) && onBehalf != address(bulker));
    }

    function testShouldNotDeployWithMorphoAddressIsZero() public {
        vm.expectRevert(IBulkerGateway.AddressIsZero.selector);
        new BulkerGateway(address(0));
    }

    function testGetters() public {
        assertEq(bulker.MORPHO(), address(morpho));
        assertEq(bulker.WETH(), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(bulker.stETH(), 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        assertEq(bulker.wstETH(), 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    }

    function testShouldApproveAfterDeploy() public {
        assertEq(ERC20(bulker.WETH()).allowance(address(bulker), address(morpho)), type(uint256).max);
        assertEq(ERC20(bulker.stETH()).allowance(address(bulker), bulker.wstETH()), type(uint256).max);
        assertEq(ERC20(bulker.wstETH()).allowance(address(bulker), address(morpho)), type(uint256).max);
    }

    function testBulkerShouldApprove(uint256 seed, uint160 amount, uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount = uint160(bound(amount, 1, type(uint160).max));
        TestMarket memory market = testMarkets[_randomUnderlying(seed)];
        address delegator = vm.addr(privateKey);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);
        (actions[0], data[0]) = _getApproveData(privateKey, market.underlying, amount, type(uint48).max, 0);

        vm.prank(delegator);
        bulker.execute(actions, data);

        (uint160 allowance, uint48 newDeadline,) = PERMIT2.allowance(delegator, market.underlying, address(bulker));
        assertEq(allowance, amount, "allowance");
        assertEq(newDeadline, type(uint48).max, "deadline");
    }

    function testBulkerShouldTransferFrom(uint256 seed, uint256 amount, uint256 privateKey) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        amount = bound(amount, 1, type(uint160).max);
        TestMarket memory market = testMarkets[_randomUnderlying(seed)];
        address delegator = vm.addr(privateKey);
        deal(market.underlying, delegator, amount);

        vm.startPrank(delegator);
        ERC20(market.underlying).safeApprove(address(Permit2Lib.PERMIT2), 0);
        ERC20(market.underlying).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](2);
        bytes[] memory data = new bytes[](2);
        (actions[0], data[0]) = _getApproveData(privateKey, market.underlying, uint160(amount), type(uint48).max, 0);
        (actions[1], data[1]) = _getTransferFromData(market.underlying, amount);

        bulker.execute(actions, data);

        assertEq(ERC20(market.underlying).balanceOf(address(bulker)), amount, "bulker balance");
    }

    function testBulkerShouldWrapETH(uint256 amount) public {
        amount = bound(amount, 1, type(uint160).max);
        deal(address(user), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWrapETHData(amount);

        vm.prank(address(user));
        bulker.execute{value: amount}(actions, data);
        assertEq(ERC20(bulker.WETH()).balanceOf(address(bulker)), amount, "bulker balance");
    }

    function testBulkerShouldUnwrapETH(uint256 amount, address receiver) public {
        _assumeTarget(receiver);
        _assumeETHReceiver(receiver);

        amount = bound(amount, 1, type(uint160).max);
        deal(wNative, amount);
        deal(wNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapETHData(amount, receiver);

        uint256 balanceBefore = receiver.balance;

        vm.prank(address(user));
        bulker.execute(actions, data);

        assertEq(ERC20(bulker.WETH()).balanceOf(address(bulker)), 0, "bulker balance");
        assertEq(receiver.balance, balanceBefore + amount, "receiver balance");
    }

    function testBulkerUnwrapETHShouldRevertIfReceiverIsZero(uint256 amount) public {
        address receiver = address(bulker);
        amount = bound(amount, 1, type(uint160).max);
        deal(wNative, amount);
        deal(wNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapETHData(amount, receiver);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldWrapStETH(uint256 amount) public {
        amount = bound(amount, 2, ILido(stETH).getCurrentStakeLimit());
        deal(address(user), type(uint256).max);

        vm.startPrank(address(user));
        ILido(stETH).submit{value: amount}(address(0));
        ERC20(stETH).transfer(address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWrapStETHData(amount);

        bulker.execute(actions, data);
        assertApproxEqAbs(
            ERC20(stNative).balanceOf(address(bulker)), IWSTETH(stNative).getWstETHByStETH(amount), 1, "bulker balance"
        );
        assertApproxEqAbs(ERC20(stETH).balanceOf(address(bulker)), 0, 1, "bulker balance"); // Approximation due to internal rounding in lido's contract.
    }

    function testBulkerShouldUnwrapStETH(uint256 amount, address receiver) public {
        _assumeTarget(receiver);

        amount = bound(amount, 1, IWSTETH(stNative).totalSupply());
        deal(stNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapStETHData(amount, receiver);

        uint256 expectedBalance = ERC20(stETH).balanceOf(receiver) + IWSTETH(stNative).getStETHByWstETH(amount);

        vm.prank(address(user));
        bulker.execute(actions, data);

        // Rounding because stETH is rebasing and therefore can have rounding errors on transfer.
        assertApproxEqAbs(ERC20(stETH).balanceOf(receiver), expectedBalance, 2, "bulker balance");
    }

    function testBulkerShouldRevertIfReceiverIsBulkerUnwrapStETH(uint256 amount) public {
        address receiver = address(bulker);
        amount = bound(amount, 1, IWSTETH(stNative).totalSupply());
        deal(stNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapStETHData(amount, receiver);

        vm.prank(address(user));

        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldSupply(uint256 seed, uint256 amount, address onBehalf, uint256 maxIterations) public {
        _assumeTarget(onBehalf);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];
        maxIterations = bound(maxIterations, 1, 10);
        amount = _boundSupply(market, amount);

        deal(market.underlying, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSupplyData(market.underlying, amount, onBehalf, maxIterations);

        vm.startPrank(address(user));
        bulker.execute(actions, data);

        assertEq(ERC20(market.underlying).balanceOf(address(bulker)), 0, "bulker balance");
        assertApproxEqAbs(morpho.supplyBalance(market.underlying, onBehalf), amount, 2, "onBehalf balance");
    }

    function testBulkerShouldSupplyCollateral(uint256 seed, uint256 amount, address onBehalf, uint256 maxIterations)
        public
    {
        _assumeTarget(onBehalf);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];
        maxIterations = bound(maxIterations, 1, 10);
        amount = _boundSupply(market, amount);

        deal(market.underlying, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSupplyCollateralData(market.underlying, amount, onBehalf);

        vm.startPrank(address(user));
        bulker.execute(actions, data);

        assertEq(ERC20(market.underlying).balanceOf(address(bulker)), 0, "bulker balance");
        assertApproxEqAbs(morpho.collateralBalance(market.underlying, onBehalf), amount, 2, "onBehalf balance");
    }

    function testBulkerShouldBorrow(uint256 seed, uint256 amount, address receiver, uint256 maxIterations) public {
        _assumeTarget(receiver);

        TestMarket storage collateralMarket = testMarkets[_randomCollateral(seed)];
        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(seed)];
        maxIterations = bound(maxIterations, 1, 10);
        amount = _boundBorrow(borrowedMarket, amount);

        uint256 collateral = collateralMarket.minBorrowCollateral(borrowedMarket, amount, eModeCategoryId);
        deal(collateralMarket.underlying, address(user), collateral);

        vm.startPrank(address(user));
        ERC20(collateralMarket.underlying).safeApprove(address(morpho), collateral);
        collateral = morpho.supplyCollateral(collateralMarket.underlying, collateral, address(user));
        morpho.approveManager(address(bulker), true);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getBorrowData(borrowedMarket.underlying, amount, receiver, maxIterations);

        uint256 balanceBefore = ERC20(borrowedMarket.underlying).balanceOf(address(receiver));

        bulker.execute(actions, data);

        assertEq(
            ERC20(borrowedMarket.underlying).balanceOf(address(receiver)), amount + balanceBefore, "bulker balance"
        );
        assertApproxEqAbs(
            morpho.borrowBalance(borrowedMarket.underlying, address(user)), amount, 2, "receiver borrow balance"
        );
    }

    function testBulkerShouldRepay(uint256 seed, uint256 amount, address onBehalf, uint256 maxIterations) public {
        _assumeTarget(onBehalf);

        TestMarket storage borrowedMarket = testMarkets[_randomBorrowableInEMode(seed)];
        maxIterations = bound(maxIterations, 1, 10);
        amount = _boundBorrow(borrowedMarket, amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        _borrowWithoutCollateral(onBehalf, borrowedMarket, amount, onBehalf, address(bulker), maxIterations);

        (actions[0], data[0]) = _getRepayData(borrowedMarket.underlying, amount, onBehalf);

        vm.prank(address(user));
        bulker.execute(actions, data);

        assertApproxEqAbs(
            morpho.borrowBalance(borrowedMarket.underlying, address(user)), 0, 2, "onBehalf borrow balance"
        );
    }

    function testBulkerShouldWithdraw(uint256 seed, uint256 amount, address receiver, uint256 maxIterations) public {
        _assumeTarget(receiver);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];
        maxIterations = bound(maxIterations, 1, 10);
        amount = _boundSupply(market, amount);

        deal(market.underlying, address(user), amount);

        vm.startPrank(address(user));

        ERC20(market.underlying).safeApprove(address(morpho), 0);
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        morpho.supply(market.underlying, amount, address(user), maxIterations);
        morpho.approveManager(address(bulker), true);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWithdrawData(market.underlying, amount, receiver, maxIterations);
        uint256 balanceBefore = ERC20(market.underlying).balanceOf(address(receiver));

        bulker.execute(actions, data);

        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(address(receiver)), amount + balanceBefore, 2, "receiver balance"
        );
    }

    function testBulkerShouldWithdrawCollateral(uint256 seed, uint256 amount, address receiver) public {
        _assumeTarget(receiver);

        TestMarket storage market = testMarkets[_randomCollateral(seed)];
        amount = _boundSupply(market, amount);
        deal(market.underlying, address(user), amount);

        vm.startPrank(address(user));

        ERC20(market.underlying).safeApprove(address(morpho), 0);
        ERC20(market.underlying).safeApprove(address(morpho), amount);

        morpho.supplyCollateral(market.underlying, amount, address(user));
        morpho.approveManager(address(bulker), true);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWithdrawCollateralData(market.underlying, amount, receiver);

        uint256 balanceBefore = ERC20(market.underlying).balanceOf(address(receiver));
        bulker.execute(actions, data);

        assertApproxEqAbs(
            ERC20(market.underlying).balanceOf(address(receiver)), amount + balanceBefore, 2, "receiver balance"
        );
    }

    function testBulkerShouldSkim(uint256 seed, uint256 amount, address receiver) public {
        _assumeTarget(receiver);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        deal(market.underlying, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSkimData(market.underlying, receiver);

        uint256 balanceBefore = ERC20(market.underlying).balanceOf(address(receiver));

        vm.prank(address(user));
        bulker.execute(actions, data);

        assertEq(ERC20(market.underlying).balanceOf(address(receiver)), amount + balanceBefore, "receiver balance");
    }

    function testBulkerSkimShouldRevertIfReceiverIsBulker(uint256 seed, uint256 amount) public {
        address receiver = address(bulker);
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        deal(market.underlying, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSkimData(market.underlying, receiver);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotAcceptETH(address sender, uint256 amount) public {
        vm.assume(sender != bulker.WETH());
        vm.assume(amount > 0 && amount <= type(uint256).max - 1 ether);

        deal(sender, amount + 1 ether);
        vm.prank(sender);

        vm.expectRevert(IBulkerGateway.OnlyWETH.selector);
        payable(address(bulker)).transfer(amount);
    }

    function testBulkerClaimRewardsShouldRevertIfRewardsManagerNotSet(address onBehalf) public {
        _assumeTarget(onBehalf);

        address[] memory assets = new address[](1);
        assets[0] = testMarkets[dai].aToken;
        morpho.setRewardsManager(address(0));

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getClaimRewardsData(assets, onBehalf);

        vm.prank(address(user));

        vm.expectRevert(IBulkerGateway.AddressIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerClaimRewards(address onBehalf) public {
        _assumeTarget(onBehalf);

        rewardsManager = IRewardsManager(new RewardsManagerMock(address(morpho)));
        morpho.setRewardsManager(address(rewardsManager));

        address[] memory assets = new address[](1);
        assets[0] = testMarkets[dai].aToken;

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getClaimRewardsData(assets, onBehalf);

        // We don't have a rewards controller on mainnet right now, so here we just test that a mock rewards manager is receiving the correct data.
        vm.prank(address(user));
        vm.expectEmit(true, true, true, true);
        emit Accrued(testMarkets[dai].aToken, address(0), onBehalf, 0, 0);
        vm.expectRevert(RewardsManagerMock.RewardsControllerCall.selector);
        bulker.execute(actions, data);
    }

    function testMultipleActions(uint256 privateKey, uint256 seed, uint256 amount, uint256 maxIterations) public {
        privateKey = bound(privateKey, 1, type(uint160).max);
        maxIterations = bound(maxIterations, 1, 10);

        TestMarket storage market = testMarkets[_randomUnderlying(seed)];
        address delegator = vm.addr(privateKey);

        amount = _boundSupply(market, amount);
        deal(market.underlying, delegator, amount);

        vm.startPrank(delegator);

        ERC20(market.underlying).safeApprove(address(Permit2Lib.PERMIT2), type(uint256).max);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](4);
        bytes[] memory data = new bytes[](4);
        (actions[0], data[0]) = _getApproveManagerData(privateKey, true, type(uint48).max);
        (actions[1], data[1]) = _getApproveData(privateKey, market.underlying, uint160(amount), type(uint48).max, 0);
        (actions[2], data[2]) = _getTransferFromData(market.underlying, amount);
        (actions[3], data[3]) = _getSupplyData(market.underlying, amount, delegator, maxIterations);

        bulker.execute(actions, data);

        assertEq(ERC20(market.underlying).balanceOf(address(bulker)), 0, "bulker balance");
        assertEq(ERC20(market.underlying).balanceOf(address(delegator)), 0, "address(user) balance");
        assertApproxEqAbs(morpho.supplyBalance(market.underlying, delegator), amount, 2, "address(user) supply");
    }

    function testBulkerShouldNotWrapEthZero(uint256 amount) public {
        amount = bound(amount, 1, type(uint160).max);
        deal(address(user), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWrapETHData(amount);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AmountIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapEthZero(uint256 amount, address receiver) public {
        _assumeTarget(receiver);
        _assumeETHReceiver(receiver);

        amount = bound(amount, 1, type(uint160).max);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapETHData(amount, receiver);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AmountIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapEthToBulker(uint256 amount) public {
        amount = bound(amount, 1, wNative.balance);
        deal(wNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapETHData(amount, address(bulker));

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapEthToZeroAddress(uint256 amount) public {
        amount = bound(amount, 1, wNative.balance);
        deal(wNative, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapETHData(amount, address(0));

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotWrapStEthZero(uint256 amount) public {
        amount = bound(amount, 1, type(uint160).max);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getWrapStETHData(amount);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AmountIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapStEthZero(uint256 amount, address receiver) public {
        _assumeTarget(receiver);

        amount = bound(amount, 1, type(uint160).max);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapStETHData(amount, receiver);

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AmountIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapStEthToBulker(uint256 amount) public {
        amount = bound(amount, 1, ERC20(stETH).balanceOf(wstETH));
        deal(wstETH, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapStETHData(amount, address(bulker));

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotUnwrapStEthToZeroAddress(uint256 amount) public {
        amount = bound(amount, 1, ERC20(stETH).balanceOf(wstETH));
        deal(wstETH, address(bulker), amount);

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getUnwrapStETHData(amount, address(0));

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotSupplyOnBehalfOfBulker(uint256 seed, uint256 amount, uint256 maxIterations) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSupplyData(market.underlying, amount, address(bulker), maxIterations);

        vm.startPrank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotSupplyCollateralOnBehalfOfBulker(uint256 seed, uint256 amount) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSupplyCollateralData(market.underlying, amount, address(bulker));

        vm.startPrank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotRepayOnBehalfOfBulker(uint256 seed, uint256 amount) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getRepayData(market.underlying, amount, address(bulker));

        vm.startPrank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotSkimToBulker(uint256 seed) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSkimData(market.underlying, address(bulker));

        vm.startPrank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotSkimToZeroAddress(uint256 seed) public {
        TestMarket storage market = testMarkets[_randomUnderlying(seed)];

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getSkimData(market.underlying, address(0));

        vm.startPrank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsZero.selector);
        bulker.execute(actions, data);
    }

    function testBulkerShouldNotClaimRewardsOnBehalfOfBulker() public {
        address[] memory assets = new address[](1);
        assets[0] = testMarkets[dai].aToken;

        IBulkerGateway.ActionType[] memory actions = new IBulkerGateway.ActionType[](1);
        bytes[] memory data = new bytes[](1);

        (actions[0], data[0]) = _getClaimRewardsData(assets, address(bulker));

        vm.prank(address(user));
        vm.expectRevert(IBulkerGateway.AddressIsBulker.selector);
        bulker.execute(actions, data);
    }

    function _getApproveData(
        uint256 privateKey,
        address underlying,
        uint160 amount,
        uint48 deadline,
        uint48 nonceOffset
    ) internal view returns (IBulkerGateway.ActionType action, bytes memory data) {
        address delegator = vm.addr(privateKey);
        action = IBulkerGateway.ActionType.APPROVE2;

        (,, uint48 nonce) = PERMIT2.allowance(delegator, underlying, address(bulker));
        nonce += nonceOffset;
        IAllowanceTransfer.PermitDetails memory details =
            IAllowanceTransfer.PermitDetails({token: underlying, amount: amount, expiration: deadline, nonce: nonce});
        IAllowanceTransfer.PermitSingle memory permitSingle =
            IAllowanceTransfer.PermitSingle({details: details, spender: address(bulker), sigDeadline: deadline});

        Types.Signature memory sig;

        bytes32 hashed = PermitHash.hash(permitSingle);
        hashed = ECDSA.toTypedDataHash(PERMIT2.DOMAIN_SEPARATOR(), hashed);

        (sig.v, sig.r, sig.s) = vm.sign(privateKey, hashed);
        data = abi.encode(underlying, amount, deadline, sig);
    }

    function _getTransferFromData(address asset, uint256 amount)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.TRANSFER_FROM2;
        data = abi.encode(asset, amount);
    }

    function _getApproveManagerData(uint256 privateKey, bool isAllowed, uint256 deadline)
        internal
        view
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        address delegator = vm.addr(privateKey);
        action = IBulkerGateway.ActionType.APPROVE_MANAGER;

        uint256 nonce = morpho.userNonce(delegator);
        SigUtils.Authorization memory authorization = SigUtils.Authorization({
            delegator: delegator,
            manager: address(bulker),
            isAllowed: isAllowed,
            nonce: nonce,
            deadline: deadline
        });

        bytes32 hashed = sigUtils.getTypedDataHash(authorization);

        Types.Signature memory sig;

        (sig.v, sig.r, sig.s) = vm.sign(privateKey, hashed);
        data = abi.encode(isAllowed, nonce, deadline, sig);
    }

    function _getSupplyData(address asset, uint256 amount, address onBehalf, uint256 maxIterations)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.SUPPLY;
        data = abi.encode(asset, amount, onBehalf, maxIterations);
    }

    function _getSupplyCollateralData(address asset, uint256 amount, address onBehalf)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.SUPPLY_COLLATERAL;
        data = abi.encode(asset, amount, onBehalf);
    }

    function _getBorrowData(address asset, uint256 amount, address receiver, uint256 maxIterations)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.BORROW;
        data = abi.encode(asset, amount, receiver, maxIterations);
    }

    function _getRepayData(address asset, uint256 amount, address onBehalf)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.REPAY;
        data = abi.encode(asset, amount, onBehalf);
    }

    function _getWithdrawData(address asset, uint256 amount, address receiver, uint256 maxIterations)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.WITHDRAW;
        data = abi.encode(asset, amount, receiver, maxIterations);
    }

    function _getWithdrawCollateralData(address asset, uint256 amount, address receiver)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.WITHDRAW_COLLATERAL;
        data = abi.encode(asset, amount, receiver);
    }

    function _getClaimRewardsData(address[] memory assets, address onBehalf)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.CLAIM_REWARDS;
        data = abi.encode(assets, onBehalf);
    }

    function _getWrapETHData(uint256 amount)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.WRAP_ETH;
        data = abi.encode(amount);
    }

    function _getUnwrapETHData(uint256 amount, address receiver)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.UNWRAP_ETH;
        data = abi.encode(amount, receiver);
    }

    function _getWrapStETHData(uint256 amount)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.WRAP_ST_ETH;
        data = abi.encode(amount);
    }

    function _getUnwrapStETHData(uint256 amount, address receiver)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.UNWRAP_ST_ETH;
        data = abi.encode(amount, receiver);
    }

    function _getSkimData(address asset, address receiver)
        internal
        pure
        returns (IBulkerGateway.ActionType action, bytes memory data)
    {
        action = IBulkerGateway.ActionType.SKIM;
        data = abi.encode(asset, receiver);
    }
}
