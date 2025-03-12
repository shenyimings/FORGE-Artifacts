// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../utils/Ownable.sol";

contract PoolCreateEvent is Ownable {

    constructor() {
        owner = msg.sender;
    }

    event PoolCreated(address indexed factory, bool indexed isApeXPool, uint256 initTimestamp, uint256 endTimestamp);

    function PoolCreate(address factory, bool isApeXPool, uint256 initTimestamp, uint256 endTimestamp) external onlyOwner {
        emit PoolCreated(factory, isApeXPool, initTimestamp, endTimestamp);
    }
}
