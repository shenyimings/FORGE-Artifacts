pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "./HProxy.sol";

contract HTokenReserveProxy is HProxy {

    constructor(address _logic, address _admin, bytes memory _data)
        HProxy (_logic, _admin, _data) public 
    {}
}
