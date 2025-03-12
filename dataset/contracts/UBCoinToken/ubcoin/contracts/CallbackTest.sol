pragma solidity ^0.4.18;

import './ReceivingContractCallback.sol';

contract CallbackTest is ReceivingContractCallback {
  
  address public from;
  uint public value;
  
  function tokenFallback(address _from, uint _value) public
  {
    from = _from;
    value = _value;
  }

}