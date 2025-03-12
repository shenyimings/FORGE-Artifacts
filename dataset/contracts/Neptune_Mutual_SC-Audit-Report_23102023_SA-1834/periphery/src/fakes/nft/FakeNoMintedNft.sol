// Neptune Mutual Protocol (https://neptunemutual.com)
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "../../nft/NeptuneLegends.sol";

contract FakeNoMintedNft is NeptuneLegends {
  function _mint(MintInfo calldata info) internal override {
    super._mint(info);
    _soulbound[info.id] = false;
    _minted[info.id] = false;
  }
}