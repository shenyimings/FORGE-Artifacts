// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IWETHGateway} from "src/interfaces/extensions/IWETHGateway.sol";

import {WETHGateway} from "src/extensions/WETHGateway.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

import "test/helpers/IntegrationTest.sol";

contract TestIntegrationWETHGateway is IntegrationTest {
    uint256 internal constant MIN_AMOUNT = 1e9;

    IWETHGateway internal wethGateway;

    function setUp() public override {
        super.setUp();

        wethGateway = new WETHGateway(address(morpho));
    }

    function invariantWETHAllowance() public {
        assertEq(ERC20(weth).allowance(address(wethGateway), address(morpho)), type(uint256).max);
    }

    function invariantETHBalance() public {
        assertEq(address(wethGateway).balance, 0);
    }

    function invariantWETHBalance() public {
        assertEq(ERC20(weth).balanceOf(address(wethGateway)), 0);
    }

    function testShouldNotPassMorphoZeroAddress() public {
        vm.expectRevert(Errors.AddressIsZero.selector);
        new WETHGateway(address(0));
    }

    function testCannotSendETHToWETHGateway(uint96 amount) public {
        vm.expectRevert(WETHGateway.OnlyWETH.selector);
        payable(address(wethGateway)).transfer(amount);
    }

    function testShouldSkim(uint256 amount) public {
        ERC20Mock erc20 = new ERC20Mock();

        deal(address(erc20), address(wethGateway), amount);
        wethGateway.skim(address(erc20));

        assertEq(erc20.balanceOf(address(wethGateway)), 0, "wethGatewayBalance");
        assertEq(erc20.balanceOf(morphoDao), amount, "morphoDaoBalance");
    }

    function testCannotSupplyETHWhenAmountIsZero(address onBehalf) public {
        onBehalf = _boundAddressValid(onBehalf);
        assertEq(morpho.supplyBalance(weth, onBehalf), 0);

        vm.expectRevert(Errors.AmountIsZero.selector);
        _supplyETH(onBehalf, 0);
    }

    function testSupplyETH(uint256 amount, address onBehalf) public {
        onBehalf = _boundAddressValid(onBehalf);
        assertEq(morpho.supplyBalance(weth, onBehalf), 0);

        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        uint256 balanceBefore = address(this).balance;
        uint256 onBehalfBalanceBefore = onBehalf.balance;
        uint256 supplied = _supplyETH(onBehalf, amount);

        if (onBehalf != address(this)) assertEq(onBehalf.balance, onBehalfBalanceBefore, "onBehalfBalance");
        assertEq(address(this).balance + amount, balanceBefore, "balanceAfter != balanceBefore - amount");
        assertEq(supplied, amount, "supplied != amount");
        assertApproxEqAbs(morpho.supplyBalance(weth, onBehalf), amount, 2, "supplyBalance != amount");
    }

    function testCannotSupplyCollateralETHWhenAmountIsZero(address onBehalf) public {
        onBehalf = _boundAddressValid(onBehalf);
        assertEq(morpho.collateralBalance(weth, onBehalf), 0);

        vm.expectRevert(Errors.AmountIsZero.selector);
        _supplyCollateralETH(onBehalf, 0);
    }

    function testSupplyCollateralETH(uint256 amount, address onBehalf) public {
        onBehalf = _boundAddressValid(onBehalf);
        assertEq(morpho.collateralBalance(weth, onBehalf), 0);

        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        uint256 balanceBefore = address(this).balance;
        uint256 onBehalfBalanceBefore = onBehalf.balance;
        uint256 supplied = _supplyCollateralETH(onBehalf, amount);

        if (onBehalf != address(this)) assertEq(onBehalf.balance, onBehalfBalanceBefore, "onBehalfBalance");
        assertEq(supplied, amount, "supplied != amount");
        assertEq(address(this).balance + amount, balanceBefore, "balanceAfter != balanceBefore - amount");
        assertApproxEqAbs(morpho.collateralBalance(weth, onBehalf), amount, 2, "collateralBalance != amount");
    }

    function testCannotWithdrawIfWETHGatewayNotManager(uint256 amount) public {
        amount = bound(amount, 1, type(uint96).max);

        _supplyETH(address(this), amount);

        vm.expectRevert(Errors.PermissionDenied.selector);
        wethGateway.withdrawETH(amount, address(this), DEFAULT_MAX_ITERATIONS);
    }

    function testCannotWithdrawETHWhenAmountIsZero(uint256 supply, address receiver) public {
        supply = bound(supply, MIN_AMOUNT, type(uint96).max);
        _supplyETH(address(this), supply);
        morpho.approveManager(address(wethGateway), true);

        vm.expectRevert(Errors.AmountIsZero.selector);
        wethGateway.withdrawETH(0, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function testWithdrawETH(uint256 supply, uint256 toWithdraw, address receiver) public {
        _assumeETHReceiver(receiver);

        supply = bound(supply, MIN_AMOUNT, type(uint96).max);
        toWithdraw = bound(toWithdraw, 1, type(uint256).max);

        _supplyETH(address(this), supply);

        morpho.approveManager(address(wethGateway), true);

        uint256 balanceBefore = address(this).balance;
        uint256 receiverBalanceBefore = receiver.balance;
        uint256 withdrawn = wethGateway.withdrawETH(toWithdraw, receiver, DEFAULT_MAX_ITERATIONS);

        if (receiver != address(this)) assertEq(address(this).balance, balanceBefore, "balanceAfter != balanceBefore");
        assertApproxEqAbs(withdrawn, Math.min(toWithdraw, supply), 2, "withdrawn != minimum");
        assertApproxEqAbs(
            morpho.supplyBalance(weth, address(this)), supply - withdrawn, 2, "supplyBalance != supply - toWithdraw"
        );
        assertApproxEqAbs(
            receiver.balance,
            receiverBalanceBefore + withdrawn,
            2,
            "receiverBalanceAfter != receiverBalanceBefore + withdrawn"
        );
    }

    function testCannotWithdrawCollateralIfWETHGatewayNotManager(uint256 amount) public {
        amount = bound(amount, 1, type(uint96).max);

        _supplyCollateralETH(address(this), amount);

        vm.expectRevert(Errors.PermissionDenied.selector);
        wethGateway.withdrawCollateralETH(amount, address(this));
    }

    function testCannotWithdrawCollateralETHWhenAmountIsZero(uint256 collateral, address receiver) public {
        collateral = bound(collateral, MIN_AMOUNT, type(uint96).max);
        _supplyCollateralETH(address(this), collateral);
        morpho.approveManager(address(wethGateway), true);

        vm.expectRevert(Errors.AmountIsZero.selector);
        wethGateway.withdrawCollateralETH(0, receiver);
    }

    function testWithdrawCollateralETH(uint256 collateral, uint256 toWithdraw, address receiver) public {
        _assumeETHReceiver(receiver);

        collateral = bound(collateral, MIN_AMOUNT, type(uint96).max);
        toWithdraw = bound(toWithdraw, 1, type(uint256).max);

        _supplyCollateralETH(address(this), collateral);

        morpho.approveManager(address(wethGateway), true);

        uint256 balanceBefore = address(this).balance;
        uint256 receiverBalanceBefore = receiver.balance;
        uint256 withdrawn = wethGateway.withdrawCollateralETH(toWithdraw, receiver);

        if (receiver != address(this)) assertEq(address(this).balance, balanceBefore, "balanceAfter != balanceBefore");
        assertApproxEqAbs(withdrawn, Math.min(toWithdraw, collateral), 2, "withdrawn != minimum");
        assertApproxEqAbs(
            morpho.collateralBalance(weth, address(this)),
            collateral - withdrawn,
            2,
            "collateralBalance != collateral - toWithdraw"
        );
        assertApproxEqAbs(
            receiver.balance,
            receiverBalanceBefore + withdrawn,
            2,
            "receiverBalanceAfter != receiverBalanceBefore + withdrawn"
        );
    }

    function testCannotBorrowIfWETHGatewayNotManager(uint256 amount) public {
        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        _supplyCollateralETH(address(this), amount);

        vm.expectRevert(Errors.PermissionDenied.selector);
        wethGateway.borrowETH(amount / 2, address(this), DEFAULT_MAX_ITERATIONS);
    }

    function testCannotBorrowETHWhenAmountIsZero(uint256 amount, address receiver) public {
        amount = bound(amount, MIN_AMOUNT, type(uint96).max);
        _supplyCollateralETH(address(this), amount);
        morpho.approveManager(address(wethGateway), true);

        vm.expectRevert(Errors.AmountIsZero.selector);
        wethGateway.borrowETH(0, receiver, DEFAULT_MAX_ITERATIONS);
    }

    function testBorrowETH(uint256 amount, address receiver) public {
        _assumeETHReceiver(receiver);

        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        _supplyCollateralETH(address(this), amount);

        morpho.approveManager(address(wethGateway), true);

        uint256 balanceBefore = receiver.balance;
        uint256 toBorrow = amount / 2;
        uint256 borrowed = wethGateway.borrowETH(toBorrow, receiver, DEFAULT_MAX_ITERATIONS);

        assertEq(borrowed, toBorrow, "borrowed != toBorrow");
        assertGt(morpho.borrowBalance(weth, address(this)), 0);
        assertApproxEqAbs(morpho.borrowBalance(weth, address(this)), toBorrow, 1);
        assertEq(receiver.balance, balanceBefore + toBorrow, "balance != expectedBalance");
    }

    function testCannotRepayETHWhenAmountZero(address repayer, address onBehalf) public {
        vm.prank(repayer);
        vm.expectRevert(Errors.AmountIsZero.selector);
        wethGateway.repayETH{value: 0}(onBehalf);
    }

    function testRepayETH(uint256 amount, uint256 toRepay, address onBehalf, address repayer) public {
        _assumeETHReceiver(onBehalf);
        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        _supplyCollateralETH(address(this), amount);

        morpho.approveManager(address(wethGateway), true);

        uint256 toBorrow = amount / 2;
        wethGateway.borrowETH(toBorrow, onBehalf, DEFAULT_MAX_ITERATIONS);

        toRepay = bound(toRepay, 1, toBorrow);
        deal(repayer, toRepay);
        vm.prank(repayer);
        uint256 repaid = wethGateway.repayETH{value: toRepay}(address(this));

        assertEq(repaid, toRepay);
        assertEq(repayer.balance, 0);
        assertApproxEqAbs(
            morpho.borrowBalance(weth, address(this)), toBorrow - toRepay, 3, "borrow balance != expected"
        );
    }

    function testRepayETHWithExcess(uint256 amount, uint256 toRepay, address onBehalf, address repayer) public {
        _assumeETHReceiver(onBehalf);
        _assumeETHReceiver(repayer);
        amount = bound(amount, MIN_AMOUNT, type(uint96).max);

        _supplyCollateralETH(address(this), amount);

        morpho.approveManager(address(wethGateway), true);

        uint256 toBorrow = amount / 2;
        wethGateway.borrowETH(toBorrow, onBehalf, DEFAULT_MAX_ITERATIONS);

        uint256 borrowBalance = morpho.borrowBalance(weth, address(this));

        toRepay = bound(toRepay, borrowBalance + 10, type(uint96).max);
        deal(repayer, toRepay);
        vm.prank(repayer);
        uint256 repaid = wethGateway.repayETH{value: toRepay}(address(this));

        assertEq(repaid, borrowBalance);
        assertEq(repayer.balance, toRepay - borrowBalance);
        assertApproxEqAbs(morpho.borrowBalance(weth, address(this)), 0, 2, "borrow balance != 0");
    }

    function _supplyETH(address onBehalf, uint256 amount) internal returns (uint256) {
        return wethGateway.supplyETH{value: amount}(onBehalf, DEFAULT_MAX_ITERATIONS);
    }

    function _supplyCollateralETH(address onBehalf, uint256 amount) internal returns (uint256) {
        return wethGateway.supplyCollateralETH{value: amount}(onBehalf);
    }

    receive() external payable {}
}
