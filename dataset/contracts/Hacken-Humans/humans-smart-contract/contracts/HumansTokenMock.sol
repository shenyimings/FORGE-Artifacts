// SPDX-License-Identifier: Humans Token AG
pragma solidity 0.8.10;

import "./HumansToken.sol";

contract HumansTokenMock is HumansToken {
  function MockTriggerTokenGenerationEvent() public onlyOwner {
    require(!_tgeInitialized, "Humans Token: Token Generation Event already triggered!");
    _initialize_tged();
    _tged -= 131500000; //50 months
  }
}
