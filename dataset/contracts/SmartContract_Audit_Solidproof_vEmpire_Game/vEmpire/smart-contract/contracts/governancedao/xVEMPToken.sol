// SPDX-License-Identifier: Unlicensed

pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

import "../common/ERC20Mintable.sol";
import "../common/ERC20Burnable.sol";

contract xVEMPToken is ERC20, ERC20Mintable, ERC20Burnable {
    
    constructor() public ERC20("xVEMP", "xVEMP"){
    }
}