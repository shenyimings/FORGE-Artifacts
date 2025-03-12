// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/strategies/GhostStrategy.sol";

contract GhostStrategyTest is Test {
    function test_strategyDoesNothing() public {
        IStrategy s = new GhostStrategy();

        assertEq(s.strategyName(), "Ghost strategy");
        assertEq(s.totalUsdValue(), 0);
        assertEq(s.assetGroupId(), 0);
        assertEq(s.assetRatio().length, 0);
        assertEq(s.assets().length, 0);
        assertEq(s.totalSupply(), 0);
        assertEq(s.balanceOf(address(1)), 0);
        assertEq(s.allowance(address(1), address(2)), 0);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        PlatformFees memory platformFees;
        s.doHardWork(
            StrategyDhwParameterBag(
                new SwapInfo[](0),
                new SwapInfo[](0),
                new uint256[](0),
                new address[](0),
                new uint256[](0),
                0,
                address(0),
                IUsdPriceFeedManager(address(0)),
                0,
                platformFees
            )
        );

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.claimShares(address(1), 10);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.releaseShares(address(1), 10);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.approve(address(1), 10);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.transferFrom(address(1), address(2), 10);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.depositFast(
            new address[](0), new uint256[](0), IUsdPriceFeedManager(address(0)), new uint256[](0), new SwapInfo[](0)
        );

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.transfer(address(1), 10);

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.redeemFast(
            0, address(1), new address[](0), new uint256[](0), IUsdPriceFeedManager(address(0)), new uint256[](0)
        );

        vm.expectRevert(abi.encodeWithSelector(IsGhostStrategy.selector));
        s.emergencyWithdraw(new uint256[](0), address(0));
    }
}
