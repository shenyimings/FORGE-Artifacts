// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IVeTetu.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IERC20.sol";

contract MockVoter is IVoter{

  address public override ve;

  constructor(address _ve) {
    ve = _ve;
  }

  function attachTokenToGauge(address, uint tokenId, address) external override {
    if (tokenId > 0) {
      IVeTetu(ve).attachToken(tokenId);
    }
  }

  function detachTokenFromGauge(address, uint tokenId, address) external override {
    if (tokenId > 0) {
      IVeTetu(ve).detachToken(tokenId);
    }
  }

  function distribute(address) external override {
    // noop
  }

  function voting(uint id) external {
    IVeTetu(ve).voting(id);
  }

  function abstain(uint id) external {
    IVeTetu(ve).abstain(id);
  }

  function detachTokenFromAll(uint tokenId, address) external override {
    while (IVeTetu(ve).attachments(tokenId) > 0) {
      IVeTetu(ve).detachToken(tokenId);
    }
    if (IVeTetu(ve).voted(tokenId) > 0) {
      IVeTetu(ve).abstain(tokenId);
    }
  }

  function notifyRewardAmount(uint amount) external override {
    IERC20(IVeTetu(ve).tokens(0)).transferFrom(msg.sender, address(this), amount);
  }

}
