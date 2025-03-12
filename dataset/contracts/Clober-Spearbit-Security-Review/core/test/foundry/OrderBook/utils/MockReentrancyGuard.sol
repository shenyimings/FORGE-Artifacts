// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.0;

import "../../../../contracts/utils/ReentrancyGuard.sol";

contract MockReentrancyGuard is ReentrancyGuard {
    function unlock() public {
        _locked = 1;
    }
}
