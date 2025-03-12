// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../libraries/Roller.sol";

contract RollerMock {
    using Roller for Roller.Snapshot;

    function cumulative(Roller.Snapshot memory snap) external view returns (int256) {
        return snap.cumulative();
    }

    function transform(
        Roller.Snapshot memory snap,
        uint256 timestamp,
        uint256 window,
        int256 value
    ) external view returns (Roller.Snapshot memory) {
        return snap.transform(timestamp, window, value);
    }
}
