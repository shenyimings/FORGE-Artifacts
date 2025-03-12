pragma solidity 0.5.12;

import "./PLibraryDelegate.sol";

contract PValidators is PLibraryDelegate {

  function () external {
    libraryDelegateFwd("LValidatorsInstance");
  }
}