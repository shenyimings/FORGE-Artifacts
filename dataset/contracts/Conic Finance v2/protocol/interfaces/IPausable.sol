// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IController.sol";

interface IPausable {
    event Paused(uint256 pausedUntil);
    event PauseDurationSet(uint256 pauseDuration);

    function controller() external view returns (IController);

    function pausedUntil() external view returns (uint256);

    function pauseDuration() external view returns (uint256);

    function isPaused() external view returns (bool);

    function setPauseDuration(uint256 _pauseDuration) external;

    function pause() external;
}
