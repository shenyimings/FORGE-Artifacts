// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {FrockTokenV1} from "../Token/FrockTokenV1.sol";

// solhint-disable-next-line no-empty-blocks
contract FrockTokenWrong is FrockTokenV1 {
    // Change the order
    bool public newVarBool;
    address public newAddress; 
    uint256 public newVar;    
}