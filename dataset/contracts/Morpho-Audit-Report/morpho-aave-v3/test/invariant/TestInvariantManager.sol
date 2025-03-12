// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "test/helpers/InvariantTest.sol";

contract TestInvariantApproveManager is InvariantTest {
    using SafeTransferLib for ERC20;

    function setUp() public virtual override {
        super.setUp();

        _targetDefaultSenders();

        _weightSelector(this.approveManager.selector, 1);

        targetSelector(FuzzSelector({addr: address(this), selectors: selectors}));
    }

    function approveManager(address manager, bool isAllowed) external {
        manager = _randomSender(manager);

        vm.prank(msg.sender);
        morpho.approveManager(manager, isAllowed);
    }

    function invariantCannotManageUnauthorized() public {
        address[] memory senders = targetSenders();

        for (uint256 i; i < allUnderlyings.length; ++i) {
            TestMarket storage market = testMarkets[allUnderlyings[i]];

            for (uint256 j; j < senders.length; ++j) {
                address manager = senders[j];

                for (uint256 k; k < senders.length; ++k) {
                    address delegator = senders[k];

                    if (delegator == manager || morpho.isManagedBy(delegator, manager)) continue;

                    vm.startPrank(manager);
                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.borrow(market.underlying, 1, delegator, delegator, 0);

                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.borrow(market.underlying, 1, delegator, manager, 0);

                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.withdraw(market.underlying, 1, delegator, delegator, 0);

                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.withdraw(market.underlying, 1, delegator, manager, 0);

                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.withdrawCollateral(market.underlying, 1, delegator, delegator);

                    vm.expectRevert(Errors.PermissionDenied.selector);
                    morpho.withdrawCollateral(market.underlying, 1, delegator, manager);
                    vm.stopPrank();
                }
            }
        }
    }
}
