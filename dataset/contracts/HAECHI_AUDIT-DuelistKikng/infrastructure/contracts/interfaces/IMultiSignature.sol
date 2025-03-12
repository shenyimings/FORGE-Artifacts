// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

interface IMultiSignature {
  function init(
    address[] memory users_,
    uint256[] memory roles_,
    int256 threshold_,
    int256 thresholdDrag_
  ) external returns (bool);
}
