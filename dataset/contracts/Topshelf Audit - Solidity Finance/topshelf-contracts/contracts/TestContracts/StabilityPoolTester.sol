// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

import "../StabilityPool.sol";

contract StabilityPoolTester is StabilityPool {

    constructor(uint _gasCompensation) public StabilityPool(_gasCompensation) {}

    function unprotectedPayable() external payable {
        ETH = ETH.add(msg.value);
    }
}
