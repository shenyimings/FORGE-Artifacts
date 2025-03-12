// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "../../interfaces/IController.sol";
import "../../interfaces/tokenomics/ICNCLockerV2.sol";
import "../../interfaces/tokenomics/ICNCLockerV2Wrapper.sol";
import "../../libraries/ScaledMath.sol";

contract CNCLockerV2Wrapper is ICNCLockerV2Wrapper {
    using ScaledMath for uint256;

    IController public immutable controller;
    ICNCLockerV2 public immutable locker;

    constructor(IController _controller, ICNCLockerV2 _locker) {
        controller = _controller;
        locker = _locker;
    }

    function balanceOf(address account) external view returns (uint256) {
        return totalVoteBoost(account);
    }

    function totalVoteBoost(address account) public view returns (uint256) {
        return
            locker.totalRewardsBoost(account).mulDown(controller.lpTokenStaker().getBoost(account));
    }
}
