// SPDX-License-Identifier: MIT

pragma solidity ^0.4.24;

import "azimuth-solidity/contracts/Polls.sol";

contract PollsWrapper is Polls {
    constructor(uint256 _pollDuration, uint256 _pollCooldown)
    public Polls(_pollDuration, _pollCooldown) {}
}
