// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IController.sol";
import "../interfaces/IPausable.sol";

abstract contract Pausable is Ownable, IPausable {
    uint256 internal constant _MIN_PAUSE_DURATION = 1 hours;
    uint256 internal constant _MAX_PAUSE_DURATION = 3 days;
    uint256 internal constant _INITIAL_PAUSE_DURATION = 3 hours;

    uint256 public pausedUntil;
    uint256 public pauseDuration;

    IController public immutable controller;

    modifier notPaused() {
        require(!isPaused(), "paused");
        _;
    }

    constructor(IController _controller) {
        controller = _controller;
        pauseDuration = _INITIAL_PAUSE_DURATION;
    }

    function setPauseDuration(uint256 _pauseDuration) external onlyOwner {
        require(_pauseDuration >= _MIN_PAUSE_DURATION, "pause duration too short");
        require(_pauseDuration <= _MAX_PAUSE_DURATION, "pause duration too long");
        pauseDuration = _pauseDuration;
        emit PauseDurationSet(pauseDuration);
    }

    function pause() external {
        require(controller.isPauseManager(msg.sender), "not pause manager");
        pausedUntil = block.timestamp + pauseDuration;
        emit Paused(pausedUntil);
    }

    function isPaused() public view override returns (bool) {
        return pausedUntil >= block.timestamp;
    }
}
