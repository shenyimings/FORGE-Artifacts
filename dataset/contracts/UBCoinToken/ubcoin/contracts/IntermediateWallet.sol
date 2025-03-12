pragma solidity ^0.4.18;

import './ownership/Ownable.sol';
import './token/ERC20Basic.sol';

contract IntermediateWallet is Ownable {
    
  ERC20Basic public token = ERC20Basic(0x2D3E7D4870a51b918919E7B851FE19983E4c38d5);
  
  address public crowdsale = 0x8DD9034f7cCC805bDc4D593A01f6A2E2EB94A67a;
    
  function retreiveTokens(address to) public onlyOwner {
    token.transfer(to, token.balanceOf(this));
  } 

  function () payable public {
    crowdsale.transfer(msg.value);
  }
    
}
