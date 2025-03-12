// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

import "../Batched/DeployAndCall.sol";

contract DeployAndCallWrapper is DeployAndCall {
  function accountFactory() external pure returns (address) {
    return address(ACCOUNT_FACTORY);
  }
}
