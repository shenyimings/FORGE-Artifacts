// SPDX-License-Identifier: UNLICENSED

pragma solidity >0.8.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract tax_token is ERC20{
    constructor() ERC20('Tax TOKEN','TX'){
     _mint(msg.sender,1000000000e18);
    }
   function _transfer(address sender, address receiver,uint256 amount) internal virtual override {
     super._transfer(sender,address(this),(amount*500)/10000);
     super._transfer(sender,receiver,amount - ((amount*500)/10000));

   }
}