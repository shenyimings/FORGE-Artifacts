//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IKAP20Committee {
  event SetCommittee(address oldCommittee, address newComittee);

  function committee() external view returns (address);

  function setCommittee(address _committee) external;
}