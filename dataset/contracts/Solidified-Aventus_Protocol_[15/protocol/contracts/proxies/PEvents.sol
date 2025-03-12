pragma solidity 0.5.12;

import "./PLibraryDelegate.sol";

contract PEvents is PLibraryDelegate {

  function () external {
    libraryDelegateFwd("LEventsInstance");
  }
}