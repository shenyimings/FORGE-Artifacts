pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;


import "../utils/Ownable.sol";

contract OwnableMock is Ownable {

  constructor(address _firstOwner) Ownable(_firstOwner) public {}

  function call_onlyOwner() external onlyOwner() returns(bool) {
    return true;
  }
  function call_anyone() external returns(bool) {
    return true;
  }

  function call_throw() external returns(bool) {
    revert(":/");
    return true;
  }

  fallback() external {}
}