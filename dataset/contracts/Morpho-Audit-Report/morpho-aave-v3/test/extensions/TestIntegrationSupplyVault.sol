// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./TestSetupVaults.sol";

contract TestIntegrationSupplyVault is TestSetupVaults {
    using WadRayMath for uint256;

    function testCorrectInitialisationDai() public {
        assertEq(daiSupplyVault.owner(), address(this));
        assertEq(daiSupplyVault.name(), "MorphoAaveDAI");
        assertEq(daiSupplyVault.symbol(), "maDAI");
        assertEq(daiSupplyVault.asset(), dai);
        assertEq(daiSupplyVault.decimals(), 18);
    }

    function testCorrectInitialisationWrappedNative() public {
        assertEq(wNativeSupplyVault.owner(), address(this));
        assertEq(wNativeSupplyVault.name(), "MorphoAaveWNATIVE");
        assertEq(wNativeSupplyVault.symbol(), "maWNATIVE");
        assertEq(wNativeSupplyVault.asset(), wNative);
        assertEq(wNativeSupplyVault.decimals(), 18);
    }

    function testShouldNotAcceptZeroInitialDeposit() public {
        SupplyVault supplyVault =
            SupplyVault(address(new TransparentUpgradeableProxy(address(supplyVaultImplV1), address(proxyAdmin), "")));

        vm.expectRevert(ISupplyVault.InitialDepositIsZero.selector);
        supplyVault.initialize(address(usdc), RECIPIENT, "MorphoAaveUSDC2", "maUSDC2", 0, 4);
    }

    function testShouldNotMintZeroShare() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        user.mintVault(daiSupplyVault, 0);
    }

    function testShouldMintAmount(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);
        uint256 shares = daiSupplyVault.convertToShares(amount);

        uint256 totalBalanceBefore = morpho.supplyBalance(dai, address(daiSupplyVault));

        user.mintVault(daiSupplyVault, shares);

        uint256 totalBalanceAfter = morpho.supplyBalance(dai, address(daiSupplyVault));

        assertEq(daiSupplyVault.balanceOf(address(user)), shares, "maDAI balance");
        assertGt(shares, 0, "shares is zero");
        assertApproxEqAbs(totalBalanceAfter, totalBalanceBefore + amount, 2, "totalBalance");
    }

    function testShouldNotDepositZero() public {
        vm.expectRevert(abi.encodeWithSignature("AmountIsZero()"));
        user.depositVault(daiSupplyVault, 0);
    }

    function testShouldDepositAmount(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 totalBalanceBefore = morpho.supplyBalance(dai, address(daiSupplyVault));

        user.depositVault(daiSupplyVault, amount);

        uint256 totalBalanceAfter = morpho.supplyBalance(dai, address(daiSupplyVault));

        assertGt(daiSupplyVault.balanceOf(address(user)), 0, "maDAI balance is zero");
        assertApproxEqAbs(totalBalanceAfter, totalBalanceBefore + amount, 2, "totalBalance");
    }

    function testShouldNotRedeemMoreShares(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 shares = user.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        user.redeemVault(daiSupplyVault, shares + 1);
    }

    function testShouldWithdrawAllAmount(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(user));
        uint256 totalBalanceBefore = morpho.supplyBalance(dai, address(daiSupplyVault));

        user.depositVault(daiSupplyVault, amount);
        user.withdrawVault(daiSupplyVault, daiSupplyVault.maxWithdraw(address(user)));

        uint256 totalBalanceAfter = morpho.supplyBalance(dai, address(daiSupplyVault));

        assertApproxEqAbs(daiSupplyVault.balanceOf(address(user)), 0, 1, "maDAI balance not zero");
        assertApproxEqAbs(ERC20(dai).balanceOf(address(user)), balanceBefore, 5, "amount withdrawn != amount deposited");
        assertApproxEqAbs(totalBalanceAfter, totalBalanceBefore, 1, "totalBalance");
    }

    function testShouldWithdrawAllUsdcAmount(uint256 amount) public {
        amount = _boundSupply(testMarkets[usdc], amount);

        uint256 balanceBeforeDeposit = ERC20(usdc).balanceOf(address(user));
        uint256 totalBalanceBefore = morpho.supplyBalance(address(usdc), address(usdcSupplyVault));

        user.depositVault(usdcSupplyVault, amount);

        uint256 balanceBeforeWithdraw = ERC20(usdc).balanceOf(address(user));
        user.withdrawVault(usdcSupplyVault, usdcSupplyVault.maxWithdraw(address(user)));

        uint256 totalBalanceAfter = morpho.supplyBalance(address(usdc), address(usdcSupplyVault));

        assertApproxEqAbs(usdcSupplyVault.balanceOf(address(user)), 0, 1, "maUSDC balance not zero");
        assertApproxEqAbs(
            ERC20(usdc).balanceOf(address(user)), balanceBeforeDeposit, 5, "amount withdrawn != amount deposited"
        );
        assertApproxEqAbs(totalBalanceAfter, totalBalanceBefore, 1, "totalBalance");
        assertApproxEqAbs(ERC20(usdc).balanceOf(address(user)) - balanceBeforeWithdraw, amount, 2, "expectedWithdraw");
    }

    function testShouldRedeemAllShares(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 balanceBefore = ERC20(dai).balanceOf(address(user));
        uint256 totalBalanceBefore = morpho.supplyBalance(address(dai), address(daiSupplyVault));

        uint256 shares = user.depositVault(daiSupplyVault, amount);
        user.redeemVault(daiSupplyVault, shares);

        uint256 totalBalanceAfter = morpho.supplyBalance(address(dai), address(daiSupplyVault));

        assertApproxEqAbs(ERC20(dai).balanceOf(address(user)), balanceBefore, 5, "amount withdrawn != amount deposited");
        assertEq(daiSupplyVault.balanceOf(address(user)), 0, "maDAI balance not zero");
        assertApproxEqAbs(totalBalanceAfter, totalBalanceBefore, 1, "totalBalance");
    }

    function testShouldNotRedeemWhenNotDeposited(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 shares = user.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: redeem more than max");
        promoter1.redeemVault(daiSupplyVault, shares);
    }

    function testShouldNotRedeemOnBehalfIfNotAllowed(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 shares = user.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC20: insufficient allowance");
        promoter1.redeemVault(daiSupplyVault, shares, address(user));
    }

    function testShouldRedeemOnBehalfIfAllowed(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        uint256 balanceBeforeDepositor = ERC20(dai).balanceOf(address(user));
        uint256 balanceBeforeRedeemer = ERC20(dai).balanceOf(address(promoter1));
        uint256 shares = user.depositVault(daiSupplyVault, amount);

        user.approve(address(maDai), address(promoter1), shares);
        promoter1.redeemVault(daiSupplyVault, shares, address(user));

        assertApproxEqAbs(ERC20(dai).balanceOf(address(user)), balanceBeforeDepositor - amount, 5, "amount deposited");
        assertApproxEqAbs(
            ERC20(dai).balanceOf(address(promoter1)), balanceBeforeRedeemer + amount, 5, "amount withdrawn"
        );
    }

    function testShouldNotWithdrawGreaterAmount(uint256 amount, uint256 amountOverdrawn) public {
        amount = _boundSupply(testMarkets[dai], amount);
        amountOverdrawn = bound(amountOverdrawn, 1, type(uint256).max - amount);

        user.depositVault(daiSupplyVault, amount);

        vm.expectRevert("ERC4626: withdraw more than max");
        user.withdrawVault(daiSupplyVault, amount + amountOverdrawn);
    }

    function testTransfer(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        user.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(user));
        vm.prank(address(user));
        daiSupplyVault.transfer(address(promoter1), balance);

        assertEq(daiSupplyVault.balanceOf(address(user)), 0);
        assertEq(daiSupplyVault.balanceOf(address(promoter1)), balance);
    }

    function testTransferFrom(uint256 amount) public {
        amount = _boundSupply(testMarkets[dai], amount);

        user.depositVault(daiSupplyVault, amount);

        uint256 balance = daiSupplyVault.balanceOf(address(user));
        vm.prank(address(user));
        daiSupplyVault.approve(address(promoter2), balance);

        vm.prank(address(promoter2));
        daiSupplyVault.transferFrom(address(user), address(promoter1), balance);

        assertEq(daiSupplyVault.balanceOf(address(user)), 0);
        assertEq(daiSupplyVault.balanceOf(address(promoter1)), balance);
    }

    function testShouldDepositCorrectAmountWhenMorphoPoolIndexesOutdated(uint256 amount, uint256 timePassed) public {
        amount = _boundSupply(testMarkets[dai], amount);
        timePassed = bound(timePassed, 1, 10 days);

        user.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + (timePassed + 19) / 20);
        vm.warp(block.timestamp + 1_000_000);

        uint256 shares = promoter1.depositVault(daiSupplyVault, amount);
        uint256 assets = promoter1.redeemVault(daiSupplyVault, shares);

        assertApproxEqAbs(assets, amount, 1, "unexpected withdrawn assets");
    }

    function testShouldRedeemAllAmountWhenMorphoPoolIndexesOutdated(uint256 amount, uint256 timePassed) public {
        amount = _boundSupply(testMarkets[dai], amount);
        timePassed = bound(timePassed, 1, 10 days);

        uint256 expectedOnPool = amount.rayDiv(pool.getReserveNormalizedIncome(dai));
        uint256 totalScaledBalanceBefore = morpho.scaledPoolSupplyBalance(address(dai), address(daiSupplyVault));

        uint256 shares = user.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + (timePassed + 19) / 20);
        vm.warp(block.timestamp + timePassed);

        uint256 assets = user.redeemVault(daiSupplyVault, shares);
        uint256 totalScaledBalanceAfter = morpho.scaledPoolSupplyBalance(address(dai), address(daiSupplyVault));

        assertApproxEqAbs(
            assets, expectedOnPool.rayMul(pool.getReserveNormalizedIncome(dai)), 3, "unexpected withdrawn assets"
        );
        assertEq(daiSupplyVault.balanceOf(address(user)), 0, "balance not zero");
        assertApproxEqAbs(totalScaledBalanceAfter, totalScaledBalanceBefore, 1, "totalBalance");
    }

    function testShouldWithdrawAllAmountWhenMorphoPoolIndexesOutdated(uint256 amount, uint256 timePassed) public {
        amount = _boundSupply(testMarkets[dai], amount);
        timePassed = bound(timePassed, 1, 10 days);

        uint256 poolIndexBefore = pool.getReserveNormalizedIncome(dai);
        uint256 totalScaledBalanceBefore = morpho.scaledPoolSupplyBalance(address(dai), address(daiSupplyVault));

        user.depositVault(daiSupplyVault, amount);

        vm.roll(block.number + (timePassed + 19) / 20);
        vm.warp(block.timestamp + timePassed);

        uint256 poolIndexAfter = pool.getReserveNormalizedIncome(dai);
        uint256 balanceBefore = ERC20(dai).balanceOf(address(user));

        user.withdrawVault(daiSupplyVault, daiSupplyVault.maxWithdraw(address(user)));

        uint256 totalScaledBalanceAfter = morpho.scaledPoolSupplyBalance(address(dai), address(daiSupplyVault));

        assertEq(daiSupplyVault.balanceOf(address(user)), 0, "balance not zero");
        assertApproxEqAbs(totalScaledBalanceAfter, totalScaledBalanceBefore, 1, "totalBalance");
        assertApproxEqAbs(
            ERC20(dai).balanceOf(address(user)) - balanceBefore,
            amount.rayDiv(poolIndexBefore).rayMul(poolIndexAfter),
            3,
            "unexpected withdrawn assets"
        );
    }

    function testShouldRevertSkimWhenRecipientZero(uint256 seed, uint256 amount) public {
        daiSupplyVault.setRecipient(address(0));
        address underlying = _randomUnderlying(seed);
        amount = _boundSupply(testMarkets[underlying], amount);

        deal(underlying, address(daiSupplyVault), amount);

        address[] memory underlyings = new address[](1);
        underlyings[0] = underlying;

        vm.expectRevert(ISupplyVault.AddressIsZero.selector);
        daiSupplyVault.skim(underlyings);
    }

    function testShouldSkim(uint256 seed, uint256 amount) public {
        address underlying = _randomUnderlying(seed);
        amount = _boundSupply(testMarkets[underlying], amount);

        deal(underlying, address(daiSupplyVault), amount);
        uint256 balanceBefore = ERC20(underlying).balanceOf(daiSupplyVault.recipient());

        address[] memory underlyings = new address[](1);
        underlyings[0] = underlying;

        daiSupplyVault.skim(underlyings);

        assertEq(ERC20(underlying).balanceOf(daiSupplyVault.recipient()), amount + balanceBefore);
        assertEq(ERC20(underlying).balanceOf(address(daiSupplyVault)), 0);
    }
}
