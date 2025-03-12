// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IPool} from "aave-v3/interfaces/IPool.sol";
import {IAToken} from "aave-v3/interfaces/IAToken.sol";
import {IVariableDebtToken} from "aave-v3/interfaces/IVariableDebtToken.sol";
import {Errors} from "aave-v3/protocol/libraries/helpers/Errors.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {Constants as C} from "../src/lib/Constants.sol";
import {scWETH} from "../src/steth/scWETH.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ILido} from "../src/interfaces/lido/ILido.sol";
import {IwstETH} from "../src/interfaces/lido/IwstETH.sol";
import {ICurvePool} from "../src/interfaces/curve/ICurvePool.sol";
import {IVault} from "../src/interfaces/balancer/IVault.sol";
import {AggregatorV3Interface} from "../src/interfaces/chainlink/AggregatorV3Interface.sol";
import {sc4626} from "../src/sc4626.sol";
import "../src/errors/scErrors.sol";

contract scWETHTest is Test {
    using FixedPointMathLib for uint256;

    uint256 mainnetFork;

    address constant keeper = address(0x05);
    address constant alice = address(0x06);
    address constant treasury = address(0x07);
    uint256 boundMinimum = 1e10; // below this amount, aave doesn't count it as collateral

    address admin = address(this);
    scWETH vault;
    uint256 initAmount = 100e18;

    WETH weth;
    ILido stEth;
    IwstETH wstEth;
    IAToken aToken;
    ERC20 debtToken;
    IPool aavePool;
    ICurvePool curvePool;
    uint256 slippageTolerance = 0.99e18;
    uint256 maxLtv;
    uint256 targetLtv = 0.7e18;

    function setUp() public {
        vm.createFork(vm.envString("RPC_URL_MAINNET"));
        vm.selectFork(mainnetFork);
        vm.rollFork(16784444);

        scWETH.ConstructorParams memory params = _createDefaultWethVaultConstructorParams();

        vault = new scWETH(params);

        // set vault eth balance to zero
        vm.deal(address(vault), 0);

        weth = vault.weth();
        stEth = vault.stEth();
        wstEth = vault.wstETH();

        maxLtv = vault.getMaxLtv();

        aToken = vault.aToken();
        debtToken = vault.variableDebtToken();
        aavePool = vault.aavePool();
        curvePool = vault.curvePool();
    }

    function test_constructor() public {
        assertEq(aavePool.getUserEMode(address(vault)), 1, "Efficiency mode not 1");
        assertEq(vault.treasury(), admin, "treasury not set");
        assertEq(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin), true, "admin role not set");
        assertEq(vault.hasRole(vault.KEEPER_ROLE(), keeper), true, "keeper role not set");
        assertEq(vault.targetLtv(), targetLtv, "targetLtv not set");
        assertEq(vault.slippageTolerance(), slippageTolerance, "slippageTolerance not set");
    }

    function test_constructor_invalidAdmin() public {
        scWETH.ConstructorParams memory params = _createDefaultWethVaultConstructorParams();
        params.admin = address(0x00); // invalid address

        vm.expectRevert(ZeroAddress.selector);
        vault = new scWETH(params);
    }

    function test_constructor_invalidKeeper() public {
        scWETH.ConstructorParams memory params = _createDefaultWethVaultConstructorParams();
        params.keeper = address(0x00); // invalid address

        vm.expectRevert(ZeroAddress.selector);
        vault = new scWETH(params);
    }

    function test_constructor_invalidTargetLtv() public {
        scWETH.ConstructorParams memory params = _createDefaultWethVaultConstructorParams();
        params.targetLtv = 0.9e18; // invalid target ltv

        vm.expectRevert(InvalidTargetLtv.selector);
        vault = new scWETH(params);
    }

    function test_constructor_invalidSlippageTolerance() public {
        scWETH.ConstructorParams memory params = _createDefaultWethVaultConstructorParams();
        params.slippageTolerance = 1.01e18; // invalid slippage tolerance

        vm.expectRevert(InvalidSlippageTolerance.selector);
        vault = new scWETH(params);
    }

    function test_setPerformanceFee() public {
        uint256 fee = 1000;
        vault.setPerformanceFee(fee);
        assertEq(vault.performanceFee(), fee);

        // revert if called by another user
        vm.expectRevert(0x06d919f2);
        vm.prank(alice);
        vault.setPerformanceFee(fee);

        vm.expectRevert(FeesTooHigh.selector);
        vault.setPerformanceFee(1.1e18);
    }

    function test_setTreasury() public {
        address newTreasury = alice;
        vault.setTreasury(newTreasury);
        assertEq(vault.treasury(), newTreasury);

        // revert if called by another user
        vm.expectRevert(0x06d919f2);
        vm.prank(alice);
        vault.setTreasury(address(this));

        vm.expectRevert(TreasuryCannotBeZero.selector);
        vault.setTreasury(address(0x00));
    }

    function test_setSlippageTolerance() public {
        vault.setSlippageTolerance(0.5e18);
        assertEq(vault.slippageTolerance(), 0.5e18, "slippageTolerance not set");

        // revert if called by another user
        vm.expectRevert(CallerNotAdmin.selector);
        vm.prank(alice);
        vault.setSlippageTolerance(0.5e18);

        vm.expectRevert(InvalidSlippageTolerance.selector);
        vault.setSlippageTolerance(1.1e18);
    }

    function test_setStEThToEthPriceFeed() public {
        address newStEthPriceFeed = alice;
        vault.setStEThToEthPriceFeed(newStEthPriceFeed);
        assertEq(address(vault.stEThToEthPriceFeed()), newStEthPriceFeed);

        // revert if called by another user
        vm.expectRevert(CallerNotAdmin.selector);
        vm.prank(alice);
        vault.setStEThToEthPriceFeed(newStEthPriceFeed);

        vm.expectRevert(ZeroAddress.selector);
        vault.setStEThToEthPriceFeed(address(0x00));
    }

    function test_deposit_redeem(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e27);
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);

        uint256 preDepositBal = weth.balanceOf(address(this));

        vault.deposit(amount, address(this));

        _depositChecks(amount, preDepositBal);

        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        _redeemChecks(preDepositBal);
    }

    function testFail_Deposit_WithInsufficientApproval(uint256 amount) public {
        vm.deal(address(this), amount / 2);
        weth.deposit{value: amount / 2}();
        weth.approve(address(vault), amount / 2);
        vault.deposit(amount, address(this));
    }

    function testFail_Withdraw(uint256 amount) public {
        vm.deal(address(this), amount / 2);
        weth.deposit{value: amount / 2}();
        weth.approve(address(vault), amount / 2);
        vault.deposit(amount / 2, address(this));
        vault.withdraw(amount, address(this), address(this));
    }

    function testFail_Redeem_WithInsufficientBalance(uint256 amount) public {
        vm.deal(address(this), amount / 2);
        weth.deposit{value: amount / 2}();
        weth.approve(address(vault), amount / 2);
        vault.deposit(amount / 2, address(this));
        vault.redeem(amount, address(this), address(this));
    }

    function testFail_Withdraw_WithNoBalance(uint256 amount) public {
        if (amount == 0) amount = 1;
        vault.withdraw(amount, address(this), address(this));
    }

    function testFail_Redeem_WithNoBalance(uint256 amount) public {
        vault.redeem(amount, address(this), address(this));
    }

    function testFail_Deposit_WithNoApproval(uint256 amount) public {
        vault.deposit(amount, address(this));
    }

    function test_atomic_deposit_invest_redeem(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e22); //max ~$280m flashloan
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);

        uint256 preDepositBal = weth.balanceOf(address(this));

        uint256 shares = vault.deposit(amount, address(this));

        _depositChecks(amount, preDepositBal);

        vm.prank(keeper);
        vault.harvest();

        // account for value loss if stETH worth less than ETH
        (, int256 price,,,) = vault.stEThToEthPriceFeed().latestRoundData();
        amount = amount.mulWadDown(uint256(price));

        // account for unrealized slippage loss
        amount = amount.mulWadDown(slippageTolerance);

        assertApproxEqRel(vault.totalAssets(), amount, 0.01e18);
        assertEq(vault.balanceOf(address(this)), shares);
        assertApproxEqRel(vault.convertToAssets(vault.balanceOf(address(this))), amount, 0.01e18);

        vault.redeem(shares, address(this), address(this));

        assertEq(vault.convertToAssets(10 ** vault.decimals()), 1e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertApproxEqRel(weth.balanceOf(address(this)), amount, 0.01e18);
    }

    function test_twoDeposits_invest_twoRedeems(uint256 depositAmount1, uint256 depositAmount2) public {
        depositAmount1 = bound(depositAmount1, boundMinimum, 10000 ether);
        depositAmount2 = bound(depositAmount2, boundMinimum, 10000 ether);

        uint256 minDelta = 0.017e18;

        uint256 shares1 = _depositToVault(address(this), depositAmount1);
        uint256 shares2 = _depositToVault(alice, depositAmount2);

        vm.prank(keeper);
        vault.harvest();

        uint256 ltv = vault.targetLtv();

        uint256 expectedRedeem = vault.previewRedeem(shares1 / 2);
        vault.redeem(shares1 / 2, address(this), address(this));
        assertApproxEqRel(weth.balanceOf(address(this)), expectedRedeem, minDelta, "redeem1");

        assertApproxEqRel(vault.getLtv(), ltv, 0.013e18, "ltv");

        expectedRedeem = vault.previewRedeem(shares2 / 2);
        vm.prank(alice);
        vault.redeem(shares2 / 2, alice, alice);
        assertApproxEqRel(weth.balanceOf(alice), expectedRedeem, minDelta, "redeem2");

        assertApproxEqRel(vault.getLtv(), ltv, 0.01e18, "ltv");

        uint256 initBalance = weth.balanceOf(address(this));
        expectedRedeem = vault.previewRedeem(shares1 / 2);
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
        assertApproxEqRel(weth.balanceOf(address(this)) - initBalance, expectedRedeem, minDelta, "redeem3");
        assertApproxEqRel(vault.getLtv(), ltv, 0.01e18, "ltv");

        initBalance = weth.balanceOf(alice);
        expectedRedeem = vault.previewRedeem(shares2 / 2);
        uint256 remainingShares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(remainingShares, alice, alice);

        assertApproxEqRel(weth.balanceOf(alice) - initBalance, expectedRedeem, 0.025e18, "redeem4");

        assertEq(vault.getLtv(), 0);
    }

    function test_applyNewTargetLtv_higherLtv(uint256 amount, uint256 newLtv) public {
        amount = bound(amount, boundMinimum, 1e20);
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        newLtv = bound(newLtv, vault.getLtv() + 1e15, maxLtv - 0.001e18);
        vault.applyNewTargetLtv(newLtv);

        assertApproxEqRel(vault.getLtv(), newLtv, 0.01e18, "leverage change failed");
    }

    function test_applyNewTargetLtv_lowerLtv(uint256 amount, uint256 newLtv) public {
        amount = bound(amount, boundMinimum, 1e20);
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        newLtv = bound(newLtv, 0.01e18, vault.getLtv() - 0.01e18);
        vault.applyNewTargetLtv(newLtv);

        // some amount will be left in vault, unrealized slippage
        assertApproxEqRel(vault.getLtv(), newLtv, 0.03e18, "leverage change failed");
    }

    function test_applyNewTargetLtv_invalidMaxLtv() public {
        uint256 amount = 100 ether;
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        vm.expectRevert(InvalidTargetLtv.selector);
        vault.applyNewTargetLtv(maxLtv + 1);
        vm.expectRevert(InvalidTargetLtv.selector);
        vault.applyNewTargetLtv(maxLtv);
    }

    function test_receiveFlashLoan_InvalidFlashLoanCaller() public {
        address[] memory empty;
        uint256[] memory amounts = new uint[](1);
        amounts[0] = 1;
        vm.expectRevert(InvalidFlashLoanCaller.selector);
        vault.receiveFlashLoan(empty, amounts, amounts, abi.encode(1));
    }

    function test_receiveFlashLoan_FailsIfInitiatorIsNotVault() public {
        IVault balancer = IVault(C.BALANCER_VAULT);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(weth);
        amounts[0] = 100e18;

        vm.expectRevert(InvalidFlashLoanCaller.selector);
        balancer.flashLoan(address(vault), tokens, amounts, abi.encode(0, 0));
    }

    function test_maxLtv(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e21);
        vm.deal(address(this), amount);

        aavePool.setUserEMode(1);

        stEth.approve(address(wstEth), type(uint256).max);
        stEth.approve(address(curvePool), type(uint256).max);
        wstEth.approve(address(aavePool), type(uint256).max);
        weth.approve(address(aavePool), type(uint256).max);
        stEth.submit{value: amount}(address(0));
        wstEth.wrap(stEth.balanceOf(address(this)));
        aavePool.supply(address(wstEth), wstEth.balanceOf(address(this)), address(this), 0);

        // borrow at max ltv should fail
        vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
        aavePool.borrow(address(weth), amount.mulWadDown(maxLtv), 2, 0, address(this));

        // borrow at a little less than maxLtv should pass without errors
        aavePool.borrow(address(weth), amount.mulWadDown(maxLtv - 1e16), 2, 0, address(this));
    }

    function test_withdraw_revert() public {
        vm.expectRevert(PleaseUseRedeemMethod.selector);
        vault.withdraw(1e18, address(this), address(this));
    }

    function test_harvest(uint256 amount, uint64 tP) public {
        amount = bound(amount, boundMinimum, 1e21);
        // simulate wstETH supply interest to EULER
        uint256 timePeriod = bound(tP, 260 days, 365 days);
        uint256 annualPeriod = 365 days;
        uint256 stEthStakingApy = 0.071e18;
        uint256 stEthStakingInterest = 1e18 + stEthStakingApy.mulDivDown(timePeriod, annualPeriod);

        _depositToVault(address(this), amount);

        vm.prank(keeper);
        vault.harvest();

        _simulate_stEthStakingInterest(timePeriod, stEthStakingInterest);

        assertEq(vault.totalProfit(), 0);

        vm.prank(keeper);
        vault.harvest();

        uint256 minimumExpectedApy = 0.07e18;

        assertGt(
            vault.totalProfit(),
            amount.mulWadDown(minimumExpectedApy.mulDivDown(timePeriod, annualPeriod)),
            "atleast 7% APY"
        );

        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertGt(
            weth.balanceOf(address(this)) - amount,
            amount.mulWadDown(minimumExpectedApy.mulDivDown(timePeriod, annualPeriod)),
            "atleast 7% APY after withdraw"
        );
    }

    function test_withdrawToVault(uint256 amount) public {
        amount = bound(amount, boundMinimum, 10000 ether);
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        _withdrawToVaultChecks(0.018e18);
    }

    function test_harvest_withdrawToVault() public {
        // amount = bound(amount, boundMinimum, 10000 ether);
        uint256 amount = 10000 ether;
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        _simulate_stEthStakingInterest(365 days, 1.071e18);

        vault.harvest();

        // harvest must automatically rebalance
        assertApproxEqRel(vault.getLtv(), vault.targetLtv(), 0.001e18, "ltv not rebalanced");

        _withdrawToVaultChecks(0.025e18);
        vm.stopPrank();

        uint256 minimumExpectedApy = 0.05e18;

        assertGt(vault.totalProfit(), amount.mulWadDown(minimumExpectedApy), "atleast 5% APY");

        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        assertGt(
            weth.balanceOf(address(this)) - amount,
            amount.mulWadDown(minimumExpectedApy - 0.005e18),
            "atleast 5% APY after withdraw"
        );
    }

    function test_harvest_performanceFees(uint256 amount) public {
        vault.setTreasury(treasury);
        amount = bound(amount, boundMinimum, 10000 ether);
        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        _simulate_stEthStakingInterest(365 days, 1.071e18);
        vault.harvest();

        uint256 balance = vault.convertToAssets(vault.balanceOf(treasury));
        uint256 profit = vault.totalProfit();
        assertApproxEqRel(balance, profit.mulWadDown(vault.performanceFee()), 0.015e18);
    }

    function test_mint_redeem(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e27);
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);

        uint256 preDepositBal = weth.balanceOf(address(this));

        uint256 shares = vault.previewMint(amount);
        vault.mint(shares, address(this));

        _depositChecks(amount, preDepositBal);

        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));

        _redeemChecks(preDepositBal);
    }

    function test_mint_invest_redeem(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e22); //max ~$280m flashloan
        vm.deal(address(this), amount);
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);

        uint256 shares = vault.previewMint(amount);
        vault.mint(shares, address(this));

        vm.prank(keeper);
        vault.harvest();

        // account for value loss if stETH worth less than ETH
        (, int256 price,,,) = vault.stEThToEthPriceFeed().latestRoundData();
        amount = amount.mulWadDown(uint256(price));

        // account for unrealized slippage loss
        amount = amount.mulWadDown(slippageTolerance);

        assertApproxEqRel(vault.totalAssets(), amount, 0.01e18);
        assertEq(vault.balanceOf(address(this)), shares);
        assertApproxEqRel(vault.convertToAssets(vault.balanceOf(address(this))), amount, 0.01e18);

        vault.redeem(shares, address(this), address(this));

        assertEq(vault.convertToAssets(10 ** vault.decimals()), 1e18);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertApproxEqRel(weth.balanceOf(address(this)), amount, 0.01e18);
    }

    function test_mint_invest_harvest_redeem(uint256 amount) public {
        vm.startPrank(alice);
        amount = bound(amount, boundMinimum, 1e22); //max ~$280m flashloan
        vm.deal(alice, amount);
        weth.deposit{value: amount}();
        weth.approve(address(vault), amount);

        uint256 shares = vault.previewMint(amount);
        vault.mint(shares, alice);
        vm.stopPrank();

        vm.prank(keeper);
        vault.harvest();

        uint256 interest = 1.071e18;
        _simulate_stEthStakingInterest(365 days, interest);
        vm.prank(keeper);
        vault.harvest();

        vm.prank(alice);
        vault.redeem(shares, alice, alice);

        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 0);
        assertGt(weth.balanceOf(alice), amount, "no profits after harvest");
    }

    function test_deposit_eth(uint256 amount) public {
        amount = bound(amount, boundMinimum, 1e21);
        vm.deal(address(this), amount);

        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(address(this).balance, amount);

        vault.deposit{value: amount}(address(this));

        assertEq(address(this).balance, 0, "eth not transferred from user");
        assertEq(vault.balanceOf(address(this)), amount, "shares not minted");
        assertEq(weth.balanceOf(address(vault)), amount, "weth not transferred to vault");
    }

    function test_deposit_rebalance_deposit_rebalance() public {
        vault.setTreasury(treasury);
        uint256 amount = 100 ether;
        _depositToVault(address(this), amount);

        vm.prank(keeper);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");

        _depositToVault(alice, amount);

        vm.prank(keeper);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");
    }

    function test_disinvest_invest_should_not_increase_invested(uint256 amount) public {
        vault.setTreasury(treasury);
        amount = bound(amount, boundMinimum, 1e21);
        _depositToVault(address(this), amount);

        vm.prank(keeper);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");

        _depositToVault(alice, amount);

        vm.prank(keeper);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");

        vm.startPrank(keeper);
        uint256 all = vault.totalInvested();
        vault.withdrawToVault(all);
        vault.harvest();
        assertApproxEqRel(all, vault.totalInvested(), 0.01e18);

        all = vault.totalInvested();
        vault.withdrawToVault(all);
        vault.harvest();
        assertApproxEqRel(all, vault.totalInvested(), 0.01e18);
        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");
    }

    // harvest should never count new deposits as profit
    function test_deposit_profit_deposit_harvest(uint256 amount) public {
        vault.setTreasury(treasury);
        amount = bound(amount, boundMinimum, 1e20);
        _depositToVault(address(this), amount);

        vm.prank(keeper);
        vault.harvest();

        assertEq(vault.balanceOf(treasury), 0, "profit must be zero");
        assertEq(vault.totalProfit(), 0, "profit must be zero");

        uint256 invested = vault.totalAssets();
        _simulate_stEthStakingInterest(365 days, 1.071e18);
        uint256 profit = vault.totalAssets() - invested;
        console.log("vault.totalProfit()", vault.totalProfit());
        console.log("profit", profit);
        _depositToVault(alice, amount);
        vm.prank(keeper);
        vault.harvest();

        // new deposits should not increase profits
        assertGt(profit, vault.totalProfit());
    }

    function test_deposit_rebalance_deposit_rebalance_withSimulatedProfits() public {
        vault.setTreasury(treasury);
        uint256 deposit1 = 10 ether;
        uint256 deposit2 = deposit1 * 10;
        uint256 deposit3 = deposit1 * 50;
        _depositToVault(address(this), deposit1);

        vm.prank(keeper);
        vault.harvest();

        _simulate_stEthStakingInterest(365 days, 1.071e18);

        _depositToVault(alice, deposit2);
        uint256 slippage = vault.totalAssets();

        vm.prank(keeper);
        vault.harvest();
        slippage -= vault.totalAssets();

        uint256 profit1 = vault.totalProfit();

        assertApproxEqRel(profit1, deposit1.mulWadDown(0.15e18) - slippage, 0.1e18);

        _simulate_stEthStakingInterest(365 days, 1.071e18);
        _depositToVault(address(this), deposit3);
        slippage = vault.totalAssets();

        vm.prank(keeper);
        vault.harvest();
        slippage -= vault.totalAssets();

        assertApproxEqRel(vault.totalProfit(), (vault.totalAssets() - deposit1 - deposit2 - deposit3), 0.01e18);
        assertApproxEqRel(
            vault.totalProfit(), profit1 + (profit1 + deposit1 + deposit2).mulWadDown(0.15e18) - slippage, 0.01e18
        );
    }

    function test_harvest_DoesntTakePerfFeeWhenRecoveringFromLoss() public {
        uint256 amount = 1 ether;
        vault.setTreasury(treasury);

        _depositToVault(address(this), amount);

        vm.startPrank(keeper);
        vault.harvest();

        // earn some profits
        _simulate_stEthStakingInterest(365 days, 1.1e18);
        vault.harvest();
        uint256 perfFees = vault.balanceOf(treasury);

        // loose some profits
        _simulate_stEthStakingInterest(365 days, 0.954545455e18);
        vault.harvest();

        // earn back some
        _simulate_stEthStakingInterest(365 days, 1.047619048e18);
        vault.harvest();

        // we should not mint any perf fee shares when recovering from a loss
        assertEq(vault.balanceOf(treasury), perfFees, "perf fee must be the same");
    }

    //////////////////////////// INTERNAL METHODS ////////////////////////////////////////

    function _createDefaultWethVaultConstructorParams() internal view returns (scWETH.ConstructorParams memory) {
        return scWETH.ConstructorParams({
            admin: admin,
            keeper: keeper,
            targetLtv: targetLtv,
            slippageTolerance: slippageTolerance,
            aavePool: IPool(C.AAVE_POOL),
            aaveAwstEth: IAToken(C.AAVE_AWSTETH_TOKEN),
            aaveVarDWeth: ERC20(C.AAVAAVE_VAR_DEBT_WETH_TOKEN),
            curveEthStEthPool: ICurvePool(C.CURVE_ETH_STETH_POOL),
            stEth: ILido(C.STETH),
            wstEth: IwstETH(C.WSTETH),
            weth: WETH(payable(C.WETH)),
            stEthToEthPriceFeed: AggregatorV3Interface(C.CHAINLINK_STETH_ETH_PRICE_FEED),
            balancerVault: IVault(C.BALANCER_VAULT)
        });
    }

    function _depositToVault(address user, uint256 amount) internal returns (uint256 shares) {
        deal(address(weth), user, amount);
        vm.startPrank(user);
        weth.approve(address(vault), amount);
        shares = vault.deposit(amount, user);
        vm.stopPrank();
    }

    function _depositChecks(uint256 amount, uint256 preDepositBal) internal {
        assertEq(vault.convertToAssets(10 ** vault.decimals()), 1e18);
        assertEq(vault.totalAssets(), amount);
        assertEq(vault.balanceOf(address(this)), amount);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), amount);
        assertEq(weth.balanceOf(address(this)), preDepositBal - amount);
    }

    function _redeemChecks(uint256 preDepositBal) internal {
        assertEq(vault.convertToAssets(10 ** vault.decimals()), 1e18);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.balanceOf(address(this)), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(address(this))), 0);
        assertEq(weth.balanceOf(address(this)), preDepositBal);
    }

    function _withdrawToVaultChecks(uint256 maxAssetsDelta) internal {
        uint256 assets = vault.totalAssets();

        assertEq(weth.balanceOf(address(vault)), 0);

        uint256 ltv = vault.getLtv();
        uint256 lev = vault.getLeverage();

        vault.withdrawToVault(assets / 2);

        // net ltv and leverage must not change after withdraw
        assertApproxEqRel(vault.getLtv(), ltv, 0.001e18);
        assertApproxEqRel(vault.getLeverage(), lev, 0.001e18);
        assertApproxEqRel(weth.balanceOf(address(vault)), assets / 2, maxAssetsDelta);

        // withdraw the remaining assets
        vault.withdrawToVault(assets / 2);

        uint256 dust = 100;
        assertLt(vault.getDebt(), dust, "test_withdrawToVault getDebt error");
        assertLt(vault.getCollateral(), dust, "test_withdrawToVault getCollateral error");
        assertApproxEqRel(weth.balanceOf(address(vault)), assets, maxAssetsDelta, "test_withdrawToVault asset balance");
    }

    function _simulate_stEthStakingInterest(uint256 timePeriod, uint256 stEthStakingInterest) internal {
        // fast forward time to simulate supply and borrow interests
        vm.warp(block.timestamp + timePeriod);
        uint256 prevBalance = read_storage_uint(address(stEth), keccak256(abi.encodePacked("lido.Lido.beaconBalance")));
        vm.store(
            address(stEth),
            keccak256(abi.encodePacked("lido.Lido.beaconBalance")),
            bytes32(prevBalance.mulWadDown(stEthStakingInterest))
        );
    }

    function read_storage_uint(address addr, bytes32 key) internal view returns (uint256) {
        return abi.decode(abi.encode(vm.load(addr, key)), (uint256));
    }

    receive() external payable {}
}
