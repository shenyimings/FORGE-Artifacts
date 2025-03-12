// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.12;

import "../../nft/interfaces/INeptuneLegends.sol";

abstract contract FakeNeptuneLegendsState is INeptuneLegends {
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  //                                           Version 1
  // ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
  bytes32 public constant NS_ROLES_ROYALTY_ADMIN = "role:royalty:admin";
  bytes32 public constant NS_ROLES_MINTER = "role:minter";
  bytes32 public constant NS_ROLES_PAUSER = "role:pauser";
  bytes32 public constant NS_ROLES_RECOVERY_AGENT = "role:recovery:agent";

  string public _uri;

  mapping(address => bool) public _pausers;
  mapping(uint256 => bool) public _minted;
  mapping(uint256 => bool) public _soulbound;
}
