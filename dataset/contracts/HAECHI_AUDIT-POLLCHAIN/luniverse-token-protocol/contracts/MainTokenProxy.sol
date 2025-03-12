pragma solidity ^0.4.24;

import "./ContractProxy.sol";

contract MainTokenProxy is ContractProxy {
  constructor(address _contractAddress) ContractProxy(_contractAddress) public {}
}
