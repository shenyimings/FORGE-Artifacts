// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    uint256 private immutable _releaseTime;

    modifier onlyUnlocked() {
        require(block.timestamp >= releaseTime(), "TokenTimelock: TIME_LOCKED");
        _;
    }

    constructor(uint256 releaseTime_) {
        // require(releaseTime_ > block.timestamp, "TokenTimelock: INVALID_RELEASE_TIME");
        _releaseTime = releaseTime_;
    }

    function releaseTime() public view virtual returns (uint256) {
        return _releaseTime;
    }

}