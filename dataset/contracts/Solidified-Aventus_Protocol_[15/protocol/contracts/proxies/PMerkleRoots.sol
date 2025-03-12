pragma solidity 0.5.12;

import "./PLibraryDelegate.sol";

contract PMerkleRoots is PLibraryDelegate {

  function () external {
    libraryDelegateFwd("LMerkleRootsInstance");
  }
}