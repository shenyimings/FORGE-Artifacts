pragma solidity 0.5.12;

import "./PLibraryDelegate.sol";

contract PMerkleLeafChallenges is PLibraryDelegate {

  function () external {
    libraryDelegateFwd("LMerkleLeafChallengesInstance");
  }
}