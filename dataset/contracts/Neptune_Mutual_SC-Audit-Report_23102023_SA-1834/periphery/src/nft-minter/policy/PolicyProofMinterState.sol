// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../../dependencies/interfaces/IStore.sol";
import "../../nft/interfaces/INeptuneLegends.sol";

abstract contract PolicyProofMinterState {
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                           Version 1
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  bytes32 public constant NS_ROLES_PAUSER = "pauser";
  bytes32 public constant NS_ROLES_RECOVERY_AGENT = "recovery:agent";

  mapping(uint256 => address) public _souls;

  IStore public _s;
  INeptuneLegends public _nft;

  uint256 public _min;
  uint256 public _max;
}
