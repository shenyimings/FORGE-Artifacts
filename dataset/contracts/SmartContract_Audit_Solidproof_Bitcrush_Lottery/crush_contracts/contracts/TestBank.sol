// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrushCoin.sol";

contract BankTest{

  CRUSHToken public crush;
  constructor( address _crush){
    crush = CRUSHToken(_crush);
  }
  function addUserLoss(uint256 _amount) external{
    require(_amount > 0, "amount cant be 0");
    crush.transferFrom(msg.sender, address(this), _amount);
  }
}