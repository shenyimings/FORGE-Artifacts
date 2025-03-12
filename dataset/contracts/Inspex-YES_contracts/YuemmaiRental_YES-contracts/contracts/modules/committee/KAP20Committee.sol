// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IKAP20Committee.sol";

abstract contract KAP20Committee is IKAP20Committee {

  address public override committee;

  modifier onlyCommittee() {
    require(msg.sender == committee, "Restricted only committee");
    _;
  }

  constructor(address committee_) {
    committee = committee_;
  }

  function _setCommittee(address _committee) internal {
    address oldCommittee = _committee;
    committee = _committee;
    emit SetCommittee(oldCommittee, committee);
  }

}