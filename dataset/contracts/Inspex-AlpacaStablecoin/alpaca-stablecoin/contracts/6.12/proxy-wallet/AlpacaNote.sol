// SPDX-License-Identifier: AGPL-3.0-or-later
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.6.12;

contract AlpacaNote {
  event LogNote(
    bytes4 indexed sig,
    address indexed guy,
    bytes32 indexed foo,
    bytes32 indexed bar,
    uint256 wad,
    bytes fax
  ) anonymous;

  modifier note() {
    bytes32 foo;
    bytes32 bar;
    uint256 wad;

    assembly {
      foo := calldataload(4)
      bar := calldataload(36)
      wad := callvalue()
    }

    _;

    emit LogNote(msg.sig, msg.sender, foo, bar, wad, msg.data);
  }
}
