pragma solidity 0.5.12;

import "./PLibraryDelegate.sol";

contract PAVTManager is PLibraryDelegate {

  function () external {
    libraryDelegateFwd("LAVTManagerInstance");
  }
}