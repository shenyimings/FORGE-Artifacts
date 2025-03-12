// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../BaseUnit.GSquared.t.sol";


contract PnLFixedRateUnitTest is BaseUnitFixture {
    function setUp() public virtual override {
        BaseUnitFixture.setUp();
    }

    function testCannotDepositAboveUtilisationUnit(
        uint128 _amount,
        uint128 _depositSenior
    ) public {
        vm.assume(_amount < 1E26);
        vm.assume(_amount > 1E20);
        vm.assume(_depositSenior > 1E18);
        uint256 amount = uint256(_amount);
        uint256 depositSenior = uint256(_depositSenior);
        uint256 shares = depositIntoVault(address(alice), amount);
        if (depositSenior < shares / 3) depositSenior = shares / 3;
        if (depositSenior > (shares - shares / 4))
            depositSenior = shares - shares / 4;

        vm.startPrank(alice);
        ERC20(address(gVault)).approve(address(gTranche), type(uint256).max);
        gTranche.deposit(shares / 4, 0, false, alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.UtilisationTooHigh.selector)
        );
        gTranche.deposit(depositSenior, 0, true, alice);
        vm.stopPrank();
    }

    function testProfitDistributionCurveUnit(
        uint256 _amount,
        uint256 _depositSenior
    ) public {
        vm.assume(_amount < 1E26);
        vm.assume(_amount > 1E20);
        vm.assume(_depositSenior > 1E20);
        uint256 amount = uint256(_amount);
        uint256 depositSenior = uint256(_depositSenior);
        uint256 shares = depositIntoVault(address(alice), amount);
        if (depositSenior > shares / 2) depositSenior = shares / 2;

        vm.startPrank(alice);
        ERC20(address(gVault)).approve(address(gTranche), type(uint256).max);
        gTranche.deposit(shares / 2, 0, false, alice);
        gTranche.deposit(depositSenior, 0, true, alice);
        vm.stopPrank();
        (uint256[2] memory initialAssets, , ) = gTranche.pnlDistribution();

        setStorage(
            address(strategy),
            threeCurveToken.balanceOf.selector,
            address(threeCurveToken),
            amount * 6
        );
        strategy.runHarvest();

        vm.warp(block.timestamp + 10000);
        (uint256[2] memory finalAssets, , ) = gTranche.pnlDistribution();
        assertGt(finalAssets[0], initialAssets[0]);
        assertGt(finalAssets[1], initialAssets[1]);
    }
}
