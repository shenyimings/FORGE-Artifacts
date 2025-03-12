// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";

// interfaces
import {IInsurance} from "../../contracts/interfaces/IInsurance.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import "../../contracts/lib/LibMath.sol";

contract Insurance is Deployment {
    // events
    event TraderBadDebtGenerated(address beneficiary, uint256 amount);
    event SystemDebtChanged(uint256 newSystemDebt);
    event InsuranceRemoved(uint256 amount);

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // addresses
    address user = address(123);
    address lp = address(456);
    address trader = address(789);

    function setUp() public virtual override {
        super.setUp();
    }

    function _dealAndApprove(address addr, uint256 quoteAmount) internal {
        deal(address(ua), addr, quoteAmount);
        vm.startPrank(addr);
        ua.approve(address(vault), quoteAmount);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 quoteAmount, uint256 baseAmount) internal {
        _dealAndApprove(addr, quoteAmount);

        vm.startPrank(addr);
        clearingHouse.deposit(quoteAmount, ua);

        clearingHouse.provideLiquidity(0, [quoteAmount / 2, baseAmount / 2], 0);
        vm.stopPrank();
    }

    function _dealAndDeposit(address addr, uint256 quoteAmount) internal {
        _dealAndApprove(addr, quoteAmount);

        vm.startPrank(addr);
        clearingHouse.deposit(quoteAmount, ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldSettleDebtWhenEnoughFunds(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256());
        deal(address(ua), address(insurance), depositAmount);

        vault.__TestVault__changeTraderBalance(user, 0, -(depositAmount.toInt256()));

        vm.expectEmit(true, true, true, false);
        emit TraderBadDebtGenerated(user, depositAmount);
        clearingHouse.seizeCollateral(user);

        assertEq(insurance.systemBadDebt(), 0);
    }

    function testFuzz_ShouldGenerateBadSystemDebtWhenEnoughAvailable(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256());
        vault.__TestVault__changeTraderBalance(user, 0, -(depositAmount.toInt256()));

        vm.expectEmit(true, true, true, false);
        emit SystemDebtChanged(depositAmount);
        vm.expectEmit(true, true, true, false);
        emit TraderBadDebtGenerated(user, depositAmount);
        clearingHouse.seizeCollateral(user);

        assertEq(insurance.systemBadDebt(), depositAmount);
    }

    function test_ShouldReturnBadDebtToVaultAndAdjustInsurance() public {
        int256 startingBadDebt = -0.15 ether;
        uint256 depositAmount = 10000 ether;

        vault.__TestVault__changeTraderBalance(user, 0, startingBadDebt);

        clearingHouse.seizeCollateral(user);

        uint256 initialSystemBadDebtBeforeTrade = insurance.systemBadDebt();

        // 1. Pay back some insurance debt but not all of it

        _dealAndProvideLiquidity(lp, depositAmount, depositAmount.wadDiv(perpetual.indexPrice().toUint256()));
        _dealAndDeposit(trader, depositAmount);

        uint256 tradeAmount = depositAmount / 100;
        uint256 expectedInsuranceFeeAmount = tradeAmount.wadMul(perpetual.insuranceFee().toUint256());
        uint256 expectedSystemBadDebtAfterFirstTrade = initialSystemBadDebtBeforeTrade - expectedInsuranceFeeAmount;
        uint256 vaultBalanceBeforeFirstTrade = ua.balanceOf(address(vault));

        vm.expectEmit(true, true, true, true, address(insurance));
        emit SystemDebtChanged(expectedSystemBadDebtAfterFirstTrade);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        uint256 systemBadDebtAfterFirstTrade = insurance.systemBadDebt();
        assertEq(systemBadDebtAfterFirstTrade, expectedSystemBadDebtAfterFirstTrade);
        uint256 vaultBalanceAfterFirstTrade = ua.balanceOf(address(vault));
        assertEq(vaultBalanceAfterFirstTrade, vaultBalanceBeforeFirstTrade);

        // 2. Pay back the rest of the insurance debt

        uint256 vaultInternalUaAccountingBeforeSecondTrade = vault.getWhiteListedCollateral(0).currentAmount;
        uint256 expectedSystemBadDebtAfterSecondTrade = 0;

        vm.expectEmit(true, true, true, true, address(insurance));
        emit SystemDebtChanged(expectedSystemBadDebtAfterSecondTrade);
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        uint256 systemBadDebtAfterSecondTrade = insurance.systemBadDebt();
        assertEq(systemBadDebtAfterSecondTrade, expectedSystemBadDebtAfterSecondTrade);

        uint256 vaultBalanceAfterSecondTrade = ua.balanceOf(address(vault));
        assertEq(vaultBalanceAfterSecondTrade, vaultBalanceAfterFirstTrade - (expectedInsuranceFeeAmount / 2));

        uint256 vaultInternalUaAccountingAfterSecondTrade = vault.getWhiteListedCollateral(0).currentAmount;
        assertEq(
            vaultInternalUaAccountingAfterSecondTrade,
            vaultInternalUaAccountingBeforeSecondTrade - expectedInsuranceFeeAmount / 2
        );

        uint256 insuranceBalanceAfterSecondTrade = ua.balanceOf(address(insurance));
        assertEq(insuranceBalanceAfterSecondTrade, expectedInsuranceFeeAmount / 2);
    }

    function testFuzz_TraderShouldPayInsuranceFeeWhenOpeningPosition(uint256 liquidityAmount) public {
        liquidityAmount = bound(liquidityAmount, 3500 ether, 100000 ether);

        // provide liquidity
        _dealAndProvideLiquidity(lp, liquidityAmount, liquidityAmount.wadDiv(perpetual.indexPrice().toUint256()));

        // deposit trader collateral
        uint256 tradeAmount = liquidityAmount / 100;
        _dealAndDeposit(trader, tradeAmount);

        int256 reserveValueBeforeTrade = vault.getReserveValue(trader, false);
        int256 feePerc = curveCryptoViews.get_dy_fees_perc(cryptoSwap, 0, 1, tradeAmount).toInt256();

        // open position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, tradeAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        LibPerpetual.TraderPosition memory position = perpetual.getTraderPosition(trader);

        int256 insurancePaid = int256(position.openNotional).wadMul(perpetual.insuranceFee());
        int256 tradingFeesPaid = int256(position.openNotional).wadMul(feePerc);

        assertEq(
            vault.getReserveValue(trader, false), reserveValueBeforeTrade - insurancePaid.abs() - tradingFeesPaid.abs()
        );
        assertEq(ua.balanceOf(address(insurance)), insurancePaid.abs().toUint256());
    }

    function testFuzz_OwnerCannotWithdrawInsuranceIfSystemBadDebtNonZero(uint256 badDebt) public {
        badDebt = bound(badDebt, 1, type(int256).max.toUint256());

        insurance.__TestInsurance__setSystemBadDebt(badDebt);

        vm.expectRevert(IInsurance.Insurance_InsufficientInsurance.selector);
        insurance.removeInsurance(0);
    }

    function testFuzz_OwnerCannotWithdrawInsuranceIfNothingToWithdraw(uint256 withdrawAmount) public {
        vm.expectRevert(IInsurance.Insurance_InsufficientInsurance.selector);
        insurance.removeInsurance(withdrawAmount);
    }

    function test_OwnerCannotWithdrawInsuranceFeesOverTenPercentOfTVL(uint256 liquidityAmount) public {
        liquidityAmount = bound(liquidityAmount, 3500 ether, 100000 ether);
        _dealAndProvideLiquidity(lp, liquidityAmount, liquidityAmount.wadDiv(perpetual.indexPrice().toUint256()));

        uint256 tvl = vault.getTotalValueLocked().toUint256();
        uint256 insuranceEarned = tvl / 9;

        uint256 maxWithdrawal = insuranceEarned - tvl.wadMul(clearingHouse.insuranceRatio());

        deal(address(ua), address(this), insuranceEarned);
        ua.transfer(address(insurance), insuranceEarned);
        assertEq(ua.balanceOf(address(insurance)), insuranceEarned);

        vm.expectRevert(IInsurance.Insurance_InsufficientInsurance.selector);
        insurance.removeInsurance(maxWithdrawal + 1);

        vm.expectEmit(true, true, true, true, address(insurance));
        emit InsuranceRemoved(maxWithdrawal);
        insurance.removeInsurance(maxWithdrawal);
    }

    function testFuzz_FundInsuranceFromClearingHouse(uint256 fundAmount, uint256 systemBadDebt) public {
        fundAmount = bound(fundAmount, 1, type(int256).max.toUint256());
        systemBadDebt = bound(systemBadDebt, 0, type(int256).max.toUint256());

        insurance.__TestInsurance__setSystemBadDebt(systemBadDebt);

        // fund vault
        deal(address(ua), address(this), fundAmount);
        ua.approve(address(vault), fundAmount);
        clearingHouse.deposit(fundAmount, ua);

        if (systemBadDebt > 0) {
            vm.expectEmit(true, true, true, true, address(insurance));
            if (fundAmount > systemBadDebt) {
                emit SystemDebtChanged(0);
            } else {
                emit SystemDebtChanged(systemBadDebt - fundAmount);
            }
        }
        insurance.__TestInsurance__fundInsurance(fundAmount);

        assertEq(insurance.systemBadDebt(), fundAmount > systemBadDebt ? 0 : systemBadDebt - fundAmount);
    }
}
