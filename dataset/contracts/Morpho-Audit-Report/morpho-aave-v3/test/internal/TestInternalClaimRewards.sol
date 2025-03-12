// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {RewardsManagerMock} from "test/mocks/RewardsManagerMock.sol";

import "test/helpers/InternalTest.sol";

contract TestInternalClaimRewards is InternalTest {
    using ConfigLib for Config;

    function setUp() public override {
        super.setUp();

        _rewardsManager = new RewardsManagerMock(address(this));
    }

    function testClaimRewardsIfNotPaused() public {
        vm.expectRevert(RewardsManagerMock.RewardsControllerCall.selector);
        this.claimRewards(new address[](0), address(this));
    }
}
