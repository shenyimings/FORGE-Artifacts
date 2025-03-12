//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Saitama is ERC20 {
    constructor() ERC20("Saitama","Saitama"){
        _mint(msg.sender,100000000*10**9);
    }   
     function decimals() public pure override returns (uint8) {
        return 9;
    }
    
}
