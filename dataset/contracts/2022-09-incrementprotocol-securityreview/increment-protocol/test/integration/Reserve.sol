// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

// contracts
import {Deployment} from "../helpers/Deployment.MainnetFork.sol";
import {TestRewardContract} from "../mocks/TestRewardContract.sol";
import {USDCMock} from "../mocks/USDCMock.sol";
import {TestERC4626} from "../mocks/TestERC4626.sol";
import {AggregatorV3Interface} from "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

// interfaces
import "../../contracts/interfaces/IClearingHouse.sol";
import "../../contracts/interfaces/IVault.sol";

// libraries
import "../../contracts/lib/LibMath.sol";
import "../../contracts/lib/LibReserve.sol";
import "../../contracts/lib/LibPerpetual.sol";
import "../../lib/forge-std/src/StdError.sol";
import "../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";

contract Reserve is Deployment {
    // events
    event Deposit(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Approval(address indexed user, address indexed receiver, uint256 tokenIdx, uint256 amount);
    event CollateralAdded(IERC20Metadata asset, uint256 weight, uint256 maxAmount);
    event OracleUpdated(address asset, AggregatorV3Interface aggregator, bool isVault);
    event CollateralWeightChanged(IERC20Metadata asset, uint256 newWeight);
    event CollateralMaxAmountChanged(IERC20Metadata asset, uint256 newMaxAmount);

    // libraries
    using LibMath for uint256;
    using LibMath for int256;

    // addresses
    address lp = address(123);
    address trader = address(456);
    address trader2 = address(789);

    // config values
    uint256 maxTradeAmount;
    uint256 minTradeAmount;
    uint24 usdcHeartBeat = 25 hours;

    function _dealAndDeposit(address addr, uint256 amount) internal {
        // deal
        deal(address(ua), addr, amount);
        vm.startPrank(addr);
        ua.approve(address(vault), amount);
        clearingHouse.deposit(amount, ua);
        vm.stopPrank();
    }

    function _dealAndProvideLiquidity(address addr, uint256 amount) internal {
        _dealAndDeposit(addr, amount);
        uint256 quoteAmount = amount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(perpetual.indexPrice().toUint256());
        vm.startPrank(addr);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();
    }

    function setUp() public override {
        super.setUp();
        maxTradeAmount = perpetual.maxPosition();
        minTradeAmount = clearingHouse.minPositiveOpenNotional();
    }

    function testFuzz_ShouldNotBeAbleToDepositUnsupportedCollateral(uint256 depositAmount) public {
        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.deposit(depositAmount, usdc);
    }

    function testFuzz_ShouldNotBeAbleToDepositToZeroAddress(uint256 depositAmount) public {
        vm.expectRevert(IClearingHouse.ClearingHouse_DepositForZeroAddress.selector);
        clearingHouse.depositFor(address(0), depositAmount, usdc);
    }

    function testFuzz_ShouldNotBeAbleToTransferUAWhenNotClearingHouseOrInsurance(uint256 depositAmount) public {
        vm.expectRevert(IVault.Vault_SenderNotInsurance.selector);
        vault.transferUa(address(usdc), depositAmount);
    }

    function testFuzz_ShouldRevertIfUserDepositsMoreThanMaxAmount(uint256 newMaxAmount, uint256 depositAmount) public {
        newMaxAmount = bound(newMaxAmount, 1, type(uint256).max - 1);
        depositAmount = bound(depositAmount, newMaxAmount + 1, type(uint256).max);

        vault.changeCollateralMaxAmount(ua, newMaxAmount);

        vm.expectRevert(IVault.Vault_MaxCollateralAmountExceeded.selector);
        clearingHouse.deposit(depositAmount, ua);
    }

    function testFuzz_CanDepositUaIntoVaultAndGetReserveValueReflectsTheAmountCorrectly(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 0, type(int256).max.toUint256());
        // deal and approve
        deal(address(ua), trader, depositAmount);
        vm.startPrank(trader);
        ua.approve(address(vault), depositAmount);
        vm.stopPrank();

        // check initial balances
        assertEq(ua.balanceOf(trader), depositAmount);
        assertEq(ua.balanceOf(address(vault)), 0);

        // should emit deposit event
        vm.expectEmit(true, true, true, true);
        emit Deposit(trader, address(ua), depositAmount);
        vm.startPrank(trader);
        clearingHouse.deposit(depositAmount, ua);
        vm.stopPrank();

        // check balances after
        assertEq(ua.balanceOf(trader), 0);
        assertEq(ua.balanceOf(address(vault)), depositAmount);

        // check getReserveValue
        assertEq(depositAmount, vault.getReserveValue(trader, false).toUint256());
        // check ua collateral
        assertEq(vault.getWhiteListedCollateral(0).currentAmount, depositAmount);
    }

    function testFuzz_CanDepositUaIntoVaultOnBehalfOfUserAndGetReserveValueReflectsTheAmountCorrectly(
        uint256 depositAmount
    ) public {
        depositAmount = bound(depositAmount, 0, type(int256).max.toUint256());
        // deal and approve
        deal(address(ua), trader, depositAmount);
        vm.startPrank(trader);
        ua.approve(address(vault), depositAmount);
        vm.stopPrank();

        // check initial balances
        assertEq(ua.balanceOf(trader), depositAmount);
        assertEq(ua.balanceOf(address(vault)), 0);

        // should emit deposit event
        vm.expectEmit(true, true, true, true);
        emit Deposit(trader2, address(ua), depositAmount);
        vm.startPrank(trader);
        clearingHouse.depositFor(trader2, depositAmount, ua);
        vm.stopPrank();

        // check balances after
        assertEq(ua.balanceOf(trader2), 0);
        assertEq(ua.balanceOf(address(vault)), depositAmount);

        // check getReserveValue
        assertEq(depositAmount, vault.getReserveValue(trader2, false).toUint256());
        // check ua collateral
        assertEq(vault.getWhiteListedCollateral(0).currentAmount, depositAmount);
    }

    function testFuzz_CanDepositUAIntoVaultAndFreeCollateralReturnsProperResult(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount * 2);
        int256 minMarginAtCreation = clearingHouse.minMarginAtCreation();

        // check initial free collateral
        assertEq(clearingHouse.getFreeCollateralByRatio(trader, minMarginAtCreation), 0);

        _dealAndDeposit(trader, depositAmount);

        // check free collateral after
        assertEq(vault.getBalance(trader, 0), depositAmount.toInt256());
        assertEq(clearingHouse.getFreeCollateralByRatio(trader, minMarginAtCreation), depositAmount.toInt256());

        // provide liquidity
        _dealAndProvideLiquidity(trader, depositAmount);

        // check values after
        int256 collateral = vault.getBalance(trader, 0);
        int256 marginRequired = clearingHouse.getTotalMarginRequirement(trader, minMarginAtCreation);
        int256 pnl = clearingHouse.getPnLAcrossMarkets(trader);
        int256 freeCollateralAfterProvidingLiquidity =
            clearingHouse.getFreeCollateralByRatio(trader, minMarginAtCreation);

        assertEq(collateral, depositAmount.toInt256() * 2);
        assertEq(freeCollateralAfterProvidingLiquidity, collateral + pnl - marginRequired);
    }

    function testFuzz_FreeCollateralDiminishesAfterProvidingLiquidity(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount * 2);
        int256 minMarginAtCreation = clearingHouse.minMarginAtCreation();

        _dealAndDeposit(trader, depositAmount);

        // get values before providing liquidity
        int256 freeCollateralAfterDeposit = clearingHouse.getFreeCollateralByRatio(trader, minMarginAtCreation);
        assertEq(vault.getBalance(trader, 0), freeCollateralAfterDeposit);

        // provide liquidity
        uint256 indexPrice = perpetual.indexPrice().toUint256();
        uint256 quoteAmount = depositAmount / 2;
        uint256 baseAmount = quoteAmount.wadDiv(indexPrice);
        vm.startPrank(trader);
        clearingHouse.provideLiquidity(0, [quoteAmount, baseAmount], 0);
        vm.stopPrank();

        // get values after
        int256 collateral = vault.getBalance(trader, 0);
        int256 unrealizedPositionPnl = clearingHouse.getPnLAcrossMarkets(trader);
        int256 absOpenNotional = clearingHouse.getDebtAcrossMarkets(trader);
        int256 expectedFreeCollateral = collateral + unrealizedPositionPnl - absOpenNotional;
        int256 freeCollateralAfterProvidingLiquidity =
            clearingHouse.getFreeCollateralByRatio(trader, minMarginAtCreation);

        // assertions
        assertLt(freeCollateralAfterProvidingLiquidity, freeCollateralAfterDeposit);
        assertLt(expectedFreeCollateral, freeCollateralAfterDeposit);
    }

    function testFuzz_DepositShouldHarmonizeCollateralDecimals(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, minTradeAmount * 2, maxTradeAmount * 2);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);

        // deal USDC and deposit
        uint256 usdcAmount = LibReserve.wadToToken(usdc.decimals(), depositAmount);
        deal(address(usdc), trader, usdcAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), usdcAmount);
        clearingHouse.deposit(usdcAmount, usdc);
        vm.stopPrank();

        // deal UA and deposit
        _dealAndDeposit(trader, depositAmount);

        assertEq(vault.getBalance(trader, 0), depositAmount.toInt256());
        assertApproxEqAbs(vault.getBalance(trader, 1), depositAmount.toInt256(), 10 ** (18 - usdc.decimals()));
    }

    function testFuzz_CollateralUSDValueShouldBeAdjustedByWeight(uint256 usdcAmount, uint256 newTokenWeight) public {
        usdcAmount = bound(usdcAmount, 0, type(int256).max.toUint256() / 1e18);
        newTokenWeight = bound(newTokenWeight, 1e17, 1 ether);

        // add USDC as collateral with new weight
        vault.addWhiteListedCollateral(usdc, newTokenWeight, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);

        // deal USDC and deposit
        deal(address(usdc), trader, usdcAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), usdcAmount);
        clearingHouse.deposit(usdcAmount, usdc);
        vm.stopPrank();

        // check reserve value
        int256 discountedUSDValue = vault.getReserveValue(trader, true);
        int256 collateralBalance = vault.getBalance(trader, 1);
        int256 oraclePrice = oracle.getPrice(address(usdc), collateralBalance);
        assertEq(discountedUSDValue, newTokenWeight.toInt256().wadMul(collateralBalance).wadMul(oraclePrice));
    }

    function testFuzz_UserReserveValueShouldBeAdjustedByWeightsOfCollateral(
        uint256 usdcAmount,
        uint256 uaAmount,
        uint256 newTokenWeight
    ) public {
        usdcAmount = bound(usdcAmount, 0, type(int256).max.toUint256() / 1e18);
        uaAmount = bound(uaAmount, 0, type(int256).max.toUint256() / 1e18);
        newTokenWeight = bound(newTokenWeight, 1e17, 1 ether);

        // add USDC as collateral with new weight
        vault.addWhiteListedCollateral(usdc, newTokenWeight, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);

        // deal USDC and deposit
        deal(address(usdc), trader, usdcAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), usdcAmount);
        clearingHouse.deposit(usdcAmount, usdc);
        vm.stopPrank();

        // check reserve value
        int256 undiscountedReserveValue = vault.__TestVault__getUserReserveValue(trader, false);
        int256 discountedReserveValue = vault.__TestVault__getUserReserveValue(trader, true);
        int256 usdcBalance = vault.getBalance(trader, 1);
        int256 oraclePrice = oracle.getPrice(address(usdc), usdcBalance);
        assertEq(undiscountedReserveValue, usdcBalance.wadMul(oraclePrice));
        assertEq(discountedReserveValue, newTokenWeight.toInt256().wadMul(usdcBalance).wadMul(oraclePrice));

        // deposit UA
        _dealAndDeposit(trader, uaAmount);

        int256 undiscountedReserveValueAfter = vault.__TestVault__getUserReserveValue(trader, false);
        int256 discountedReserveValueAfter = vault.__TestVault__getUserReserveValue(trader, true);

        assertEq(undiscountedReserveValueAfter, undiscountedReserveValue + uaAmount.toInt256());
        assertEq(discountedReserveValueAfter, discountedReserveValue + uaAmount.toInt256());
    }

    function test_UserReserveValueWithoutAnyBalances() public {
        int256 reserveValue = vault.__TestVault__getUserReserveValue(trader, false);
        assertEq(reserveValue, 0);
        int256 reserveValueDiscounted = vault.__TestVault__getUserReserveValue(trader, true);
        assertEq(reserveValueDiscounted, 0);
    }

    function testFuzz_ShouldBeAbleToDepositWhitelistedCollateralsOtherThanUA(uint256 usdcAmount) public {
        usdcAmount = bound(usdcAmount, 0, type(int256).max.toUint256() / 1e18);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);

        // deal USDC and approve
        deal(address(usdc), trader, usdcAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), usdcAmount);
        vm.stopPrank();

        // deposit and emit event
        vm.expectEmit(true, true, true, true);
        emit Deposit(trader, address(usdc), usdcAmount);
        vm.startPrank(trader);
        clearingHouse.deposit(usdcAmount, usdc);
        vm.stopPrank();

        // check balances after
        assertEq(usdc.balanceOf(trader), 0);
        assertEq(usdc.balanceOf(address(vault)), usdcAmount);

        // check getReserveValue
        int256 usdcBalance = vault.getBalance(trader, 1);
        int256 oraclePrice = oracle.getPrice(address(usdc), usdcBalance);
        assertEq(vault.getReserveValue(trader, false), usdcBalance.wadMul(oraclePrice));
    }

    function testFuzz_ShouldBeAbleToDepositAndWithdrawWhitelistedCollateralsWithUnusuallyLargeDecimals(
        uint256 decimals,
        uint256 depositAmount
    ) public {
        depositAmount = bound(depositAmount, 0, type(int256).max.toUint256() / 1e18);
        decimals = bound(decimals, 19, 30);

        // create token with large decimals
        USDCMock token = new USDCMock("USD Coin", "USDC", uint8(decimals));

        // add token as collateral
        vault.addWhiteListedCollateral(token, 1 ether, type(uint256).max);
        oracle.setOracle(address(token), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(token), 1 ether);

        // create balance and approve
        uint256 bigBalance = LibReserve.wadToToken(token.decimals(), depositAmount);
        deal(address(token), trader, bigBalance);
        vm.startPrank(trader);
        token.approve(address(vault), bigBalance);
        vm.stopPrank();

        // deposit and emit event
        vm.expectEmit(true, true, true, true);
        emit Deposit(trader, address(token), bigBalance);
        vm.startPrank(trader);
        clearingHouse.deposit(bigBalance, token);
        vm.stopPrank();

        // check balances after
        assertEq(token.balanceOf(trader), 0);
        assertEq(token.balanceOf(address(vault)), bigBalance);

        // check getReserveValue
        int256 tokenBalance = vault.getBalance(trader, 1);
        int256 oraclePrice = oracle.getPrice(address(token), tokenBalance);
        assertEq(
            vault.getReserveValue(trader, false),
            LibReserve.tokenToWad(token.decimals(), bigBalance).toInt256().wadMul(oraclePrice)
        );

        // collateral amount should be updated
        uint256 currentAmount = vault.getWhiteListedCollateral(1).currentAmount;
        assertEq(currentAmount, LibReserve.tokenToWad(token.decimals(), bigBalance));

        // withdrawal should emit event
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(token), bigBalance);
        vm.startPrank(trader);
        clearingHouse.withdraw(bigBalance, token);
        vm.stopPrank();

        // check balances after
        assertEq(token.balanceOf(trader), bigBalance);
        assertEq(token.balanceOf(address(vault)), 0);
    }

    function testFuzz_ReserveValueShouldAccountForAmountDepositedInAllWhitelistedCollaterals(uint256 depositAmount)
        public
    {
        depositAmount = bound(depositAmount, 0, type(int256).max.toUint256() / 1e18);

        // add token as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and deposit
        deal(address(usdc), trader, depositAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), depositAmount);
        vm.stopPrank();
        vm.startPrank(trader);
        clearingHouse.deposit(depositAmount, usdc);
        vm.stopPrank();

        // deal UA and deposit
        _dealAndDeposit(trader, depositAmount);

        int256 uaBalance = vault.getBalance(trader, 0);
        int256 usdcBalance = vault.getBalance(trader, 1);

        assertEq(
            (uaBalance.toUint256() + LibReserve.wadToToken(usdc.decimals(), usdcBalance.toUint256())), depositAmount * 2
        );
    }

    function testFuzz_ShouldNotBeAbleToApproveZeroAddress(uint256 allowanceAmount) public {
        vm.expectRevert(IVault.Vault_ApproveZeroAddress.selector);
        clearingHouse.increaseAllowance(address(0), allowanceAmount, ua);
    }

    function testFuzz_ShouldNotBeAbleToApproveUnsupportedToken(
        uint256 allowanceAmount,
        address approvee,
        IERC20Metadata randomToken
    ) public {
        vm.assume(address(randomToken) != address(ua));
        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.increaseAllowance(approvee, allowanceAmount, randomToken);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.decreaseAllowance(approvee, allowanceAmount, randomToken);
    }

    function testFuzz_ShouldBeAbleToApproveAnotherAccountToWithdrawTokens(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 0, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // increase allowance
        uint256 tokenIdx = vault.tokenToCollateralIdx(ua);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount, ua);
        vm.stopPrank();

        // check values
        assertEq(viewer.getAllowance(trader, trader2, tokenIdx), depositAmount);

        // decrease allowance
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, 0);
        vm.startPrank(trader);
        clearingHouse.decreaseAllowance(trader2, depositAmount, ua);
        vm.stopPrank();

        // check values
        assertEq(viewer.getAllowance(trader, trader2, tokenIdx), 0);
    }

    function testFuzz_ShouldNotBeAbleToExecuteDelegatedWithdrawalFromUserWithDifferentToken(uint256 depositAmount)
        public
    {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and deposit
        deal(address(usdc), trader, depositAmount);

        // deal UA and deposit
        _dealAndDeposit(trader, depositAmount);

        // increase allowance
        uint256 tokenIdx = vault.tokenToCollateralIdx(ua);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount, ua);
        vm.stopPrank();

        // attempt to withdraw usdc from trader
        vm.expectRevert(IVault.Vault_WithdrawInsufficientAllowance.selector);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, depositAmount, usdc);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotBeAbleToWithdrawFromUserWithoutSufficientAllowance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 2, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // approve just under the depositAmount
        uint256 tokenIdx = vault.tokenToCollateralIdx(ua);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount - 1);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount - 1, ua);
        vm.stopPrank();

        // attempt to withdraw from trader
        vm.expectRevert(IVault.Vault_WithdrawInsufficientAllowance.selector);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, depositAmount, ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotBeAbleToWithdrawWithoutSufficientVaultBalance(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // increase allowance above balance
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount + 1, ua);
        vm.stopPrank();

        // attempt to withdraw from trader
        vm.expectRevert(IVault.Vault_WithdrawExcessiveAmount.selector);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, depositAmount + 1, ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotBeAbleToWithdrawFromUserWithUADebt(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and deposit
        deal(address(usdc), trader, depositAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), depositAmount);
        clearingHouse.deposit(depositAmount, usdc);
        vm.stopPrank();

        // increase allowance
        uint256 tokenIdx = vault.tokenToCollateralIdx(usdc);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount, usdc);
        vm.stopPrank();

        // creaete ua debt
        uint256 uaIdx = vault.tokenToCollateralIdx(ua);
        int256 reserveValue = vault.getReserveValue(trader, false);
        vault.__TestVault__changeTraderBalance(trader, uaIdx, -(reserveValue + 1));

        // attempt to withdraw from trader
        vm.expectRevert(IVault.Vault_UADebt.selector);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, depositAmount, usdc);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotBeAbleToWithdrawCollateralFromUserIfItPutsThemUnderMarginRequirements(
        uint256 depositAmount
    ) public {
        depositAmount = bound(depositAmount, minTradeAmount, maxTradeAmount);

        _dealAndProvideLiquidity(lp, depositAmount * 2);
        _dealAndDeposit(trader, depositAmount);

        // create trader position
        vm.startPrank(trader);
        clearingHouse.changePosition(0, depositAmount, 0, LibPerpetual.Side.Long);
        vm.stopPrank();

        // increase allowance
        uint256 tokenIdx = vault.tokenToCollateralIdx(ua);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount, ua);
        vm.stopPrank();

        // attempt to withdraw from trader
        int256 uaBalance = vault.getBalance(trader, 0);
        vm.expectRevert(IClearingHouse.ClearingHouse_WithdrawInsufficientMargin.selector);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, uaBalance.toUint256(), ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldBeAbleToWithdrawTokensOnBehalfOfAnotherUser(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        uint256 balanceBefore = ua.balanceOf(trader2);

        // increase allowance
        uint256 tokenIdx = vault.tokenToCollateralIdx(ua);
        vm.expectEmit(true, true, true, true);
        emit Approval(trader, trader2, tokenIdx, depositAmount);
        vm.startPrank(trader);
        clearingHouse.increaseAllowance(trader2, depositAmount, ua);
        vm.stopPrank();

        // withdraw from trader
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(ua), depositAmount);
        vm.startPrank(trader2);
        clearingHouse.withdrawFrom(trader, depositAmount, ua);
        vm.stopPrank();

        assertEq(ua.balanceOf(trader2), balanceBefore + depositAmount);
        assertEq(viewer.getAllowance(trader, trader2, tokenIdx), 0);
    }

    function testFuzz_ShouldNotBeAbleToWithdrawUnsupportedCollateral(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.withdraw(depositAmount, usdc);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.withdrawAll(usdc);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        clearingHouse.withdrawFrom(trader, depositAmount, usdc);
    }

    function testFuzz_ShouldNotBeAbleToWithdrawCollateralWithUADebt(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 2, type(int256).max.toUint256() / 1e18);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and depsoit
        deal(address(usdc), trader, depositAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), depositAmount);
        clearingHouse.deposit(depositAmount, usdc);
        vm.stopPrank();

        // create ua debt
        uint256 uaIdx = vault.tokenToCollateralIdx(ua);
        int256 reserveValue = vault.getReserveValue(trader, false);
        vault.__TestVault__changeTraderBalance(trader, uaIdx, -(reserveValue + 1));

        // should revert
        vm.expectRevert(IVault.Vault_UADebt.selector);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount, usdc);
        vm.stopPrank();
    }

    function testFuzz_ShouldBeAbleToWithdrawWhitelistedCollateral(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and depsoit
        deal(address(usdc), trader, depositAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), depositAmount);
        clearingHouse.deposit(depositAmount, usdc);
        vm.stopPrank();

        // withdraw
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(usdc), depositAmount);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount, usdc);
        vm.stopPrank();
    }

    function testFuzz_ShouldBeAbleToWithdrawUA(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // withdraw
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(ua), depositAmount);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount, ua);
        vm.stopPrank();

        // check balances
        assertEq(ua.balanceOf(trader), depositAmount);
        assertEq(ua.balanceOf(address(vault)), 0);
    }

    function testFuzz_ShouldWithdrawAllUA(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // withdraw
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(ua), depositAmount);
        vm.startPrank(trader);
        clearingHouse.withdrawAll(ua);
        vm.stopPrank();

        // check balances
        assertEq(ua.balanceOf(trader), depositAmount);
        assertEq(ua.balanceOf(address(vault)), 0);
    }

    function testFuzz_ShouldNotWithdrawMoreThanUADeposited(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 2, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // withdraw
        vm.expectRevert(IVault.Vault_WithdrawExcessiveAmount.selector);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount + 1, ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotWithdrawOtherTokenTHanDeposited(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 2, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        // withdraw
        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount, usdc);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotAccessVaultDirectly(
        address caller,
        address addr1,
        address addr2,
        uint256 depositAmount,
        IERC20Metadata token,
        int256 pnl
    ) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);
        vm.assume(caller != address(clearingHouse));
        vm.startPrank(caller);

        vm.expectRevert(IVault.Vault_SenderNotClearingHouse.selector);
        vault.deposit(addr1, addr2, depositAmount, token);

        vm.expectRevert(IVault.Vault_SenderNotClearingHouse.selector);
        vault.withdraw(addr1, depositAmount, token);

        vm.expectRevert(IVault.Vault_SenderNotClearingHouse.selector);
        vault.settlePnL(addr1, pnl);
    }

    function testFuzz_ShouldNotBeAbleToWithdrawMoreTHanAvailableInVault(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 2, type(int256).max.toUint256() / 1e18);

        _dealAndDeposit(trader, depositAmount);

        vault.__TestVault__transferOut(trader, ua, depositAmount);

        vm.expectRevert(IVault.Vault_InsufficientBalance.selector);
        vm.startPrank(trader);
        clearingHouse.withdraw(depositAmount, ua);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotAddCollateralWithoutGovPermissions(IERC20Metadata token, address caller) public {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(clearingHouse.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(caller);
        vault.addWhiteListedCollateral(token, 1 ether, type(uint256).max);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotAddCollateralWithInsufficientWeight(uint256 weight) public {
        weight = bound(weight, 0, 1e17 - 1);

        vm.expectRevert(IVault.Vault_InsufficientCollateralWeight.selector);
        vault.addWhiteListedCollateral(usdc, weight, type(uint256).max);
    }

    function testFuzz_ShouldNotAddCollateralWithExcessiveWeight(uint256 weight) public {
        weight = bound(weight, 1 ether + 1, type(uint256).max);

        vm.expectRevert(IVault.Vault_ExcessiveCollateralWeight.selector);
        vault.addWhiteListedCollateral(usdc, weight, type(uint256).max);
    }

    function test_ShouldNotAddCollateralIfAlreadyAdded() public {
        vm.expectRevert(IVault.Vault_CollateralAlreadyWhiteListed.selector);
        vault.addWhiteListedCollateral(ua, 1 ether, type(uint256).max);
    }

    function testFuzz_ShouldFailToGetWhitelistedUnsupportedCollateral(uint256 idx) public {
        idx = bound(idx, vault.getNumberOfCollaterals(), type(uint256).max);
        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        vault.getWhiteListedCollateral(idx);
    }

    function testFuzz_ShouldAddCollateralIfNotAlreadyListed(uint256 weight, uint256 maxAmount) public {
        weight = bound(weight, 1e17, 1 ether);

        uint256 numCollaterals = vault.getNumberOfCollaterals();
        assertEq(numCollaterals, 1);

        vm.expectEmit(true, true, true, true);
        emit CollateralAdded(IERC20Metadata(usdc), weight, maxAmount);
        vault.addWhiteListedCollateral(usdc, weight, maxAmount);

        uint256 numCollateralsAfter = vault.getNumberOfCollaterals();
        assertEq(numCollateralsAfter, 2);

        IVault.Collateral memory collateral = vault.getWhiteListedCollateral(1);

        assertEq(address(collateral.asset), address(usdc));
        assertEq(collateral.weight, weight);
        assertEq(collateral.decimals, usdc.decimals());
        assertEq(collateral.currentAmount, 0);
        assertEq(collateral.maxAmount, maxAmount);

        assertEq(vault.tokenToCollateralIdx(usdc), 1);
    }

    function testFuzz_ShouldNotChangeCollateralParametersWithoutGovPermissions(
        address caller,
        uint256 weight,
        uint256 maxAmount
    ) public {
        weight = bound(weight, 1e17, 1 ether);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(clearingHouse.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(caller);
        vault.changeCollateralWeight(ua, weight);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(clearingHouse.GOVERNANCE()), 32)
            )
        );
        vm.startPrank(caller);
        vault.changeCollateralMaxAmount(ua, maxAmount);
        vm.stopPrank();
    }

    function testFuzz_ShouldNotChangeCollateralParametersOfUnlistedCollateral(uint256 weight, uint256 maxAmount)
        public
    {
        weight = bound(weight, 1e17, 1 ether);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        vault.changeCollateralWeight(usdc, weight);

        vm.expectRevert(IVault.Vault_UnsupportedCollateral.selector);
        vault.changeCollateralMaxAmount(usdc, maxAmount);
    }

    function testFuzz_ShouldNotChangeWeightToInsufficientAmount(uint256 weight) public {
        weight = bound(weight, 0, 1e17 - 1);

        vm.expectRevert(IVault.Vault_InsufficientCollateralWeight.selector);
        vault.changeCollateralWeight(ua, weight);
    }

    function testFuzz_ShouldNotChangeWeightToExcessiveAmount(uint256 weight) public {
        weight = bound(weight, 1 ether + 1, type(uint256).max);

        vm.expectRevert(IVault.Vault_ExcessiveCollateralWeight.selector);
        vault.changeCollateralWeight(ua, weight);
    }

    function testFuzz_ShouldChangeWeightWithinBounds(uint256 weight) public {
        weight = bound(weight, 1e17, 1 ether);

        vm.expectEmit(true, true, true, true);
        emit CollateralWeightChanged(IERC20Metadata(ua), weight);
        vault.changeCollateralWeight(ua, weight);

        IVault.Collateral memory collateral = vault.getWhiteListedCollateral(0);
        assertEq(collateral.weight, weight);
    }

    function testFuzz_ShouldChangeMaxAmountAsOwner(uint256 maxAmount) public {
        maxAmount = bound(maxAmount, 0, type(uint256).max);

        vm.expectEmit(true, true, true, true);
        emit CollateralMaxAmountChanged(IERC20Metadata(ua), maxAmount);
        vault.changeCollateralMaxAmount(ua, maxAmount);

        IVault.Collateral memory collateral = vault.getWhiteListedCollateral(0);
        assertEq(collateral.maxAmount, maxAmount);
    }

    function testFuzz_ShouldSupportERC4626Collateral(uint256 depositAmount) public {
        depositAmount = bound(depositAmount, 1, type(int256).max.toUint256() / 1e18);

        // add USDC to oracle
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // create vault token
        TestERC4626 vaultToken = new TestERC4626("Mock aUSDC Vault", "Mock Aave USD Token Vault", usdc);
        assertEq(vaultToken.decimals(), 18);

        // add vault token as collateral
        vault.addWhiteListedCollateral(vaultToken, 1 ether, type(uint256).max);

        // set oracle for vault token
        vm.expectEmit(true, true, true, true);
        emit OracleUpdated(address(usdc), usdcOracle, true);
        oracle.setOracle(address(vaultToken), usdcOracle, usdcHeartBeat, true);
        oracle.setFixedPrice(address(vaultToken), 1 ether);

        // deal USDC and deposit into vault
        deal(address(usdc), trader, depositAmount);
        assertEq(usdc.balanceOf(trader), depositAmount);

        // deposit into vault
        vm.startPrank(trader);
        usdc.approve(address(vaultToken), depositAmount);
        vaultToken.deposit(depositAmount, trader);
        vm.stopPrank();

        // check balances
        assertEq(usdc.balanceOf(address(vaultToken)), depositAmount);
        uint256 shares = vaultToken.balanceOf(trader);
        assertEq(shares, LibReserve.tokenToWad(usdc.decimals(), depositAmount));

        // price after one deposit
        assertEq(vaultToken.convertToAssets(shares), depositAmount);
        assertEq(oracle.getPrice(address(vaultToken), 1 ether), 1 ether);
        assertEq(oracle.getPrice(address(usdc), 1 ether), 1 ether);

        // increase price of vault token
        deal(address(usdc), address(this), depositAmount);
        usdc.transfer(address(vaultToken), depositAmount);

        // check balances
        assertEq(usdc.balanceOf(address(vaultToken)), depositAmount * 2);

        // price after two deposits
        assertEq(vaultToken.convertToAssets(shares), depositAmount * 2);
        assertEq(oracle.getPrice(address(vaultToken), 1 ether), 2 ether);
    }

    function testFuzz_TVLOnlyCountsNonZeroCollateralBalances(uint256 usdcAmount) public {
        usdcAmount = bound(usdcAmount, 1 ether, uint256(type(int256).max) / 1e18);
        uint256 uaAmount = LibReserve.tokenToWad(usdc.decimals(), usdcAmount);

        // add USDC as collateral
        vault.addWhiteListedCollateral(usdc, 1 ether, type(uint256).max);
        oracle.setOracle(address(usdc), usdcOracle, usdcHeartBeat, false);
        oracle.setFixedPrice(address(usdc), 1 ether);

        // deal USDC and deposit
        deal(address(usdc), trader, usdcAmount);
        vm.startPrank(trader);
        usdc.approve(address(vault), usdcAmount);
        clearingHouse.deposit(usdcAmount, usdc);
        vm.stopPrank();

        // deal UA and deposit
        _dealAndDeposit(trader, uaAmount);

        // check TVL
        assertEq(vault.getTotalValueLocked().toUint256(), uaAmount * 2);

        // withdraw all USDC
        vm.expectEmit(true, true, true, true);
        emit Withdraw(trader, address(usdc), usdcAmount);
        vm.startPrank(trader);
        clearingHouse.withdraw(usdcAmount, usdc);
        vm.stopPrank();

        // check TVL
        assertEq(vault.getTotalValueLocked().toUint256(), uaAmount);
    }
}
