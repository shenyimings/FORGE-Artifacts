// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.7;
import "../UniswapV2Factory.sol";

contract factory is UniswapV2Factory{

    constructor() UniswapV2Factory(msg.sender) public{

    }

}