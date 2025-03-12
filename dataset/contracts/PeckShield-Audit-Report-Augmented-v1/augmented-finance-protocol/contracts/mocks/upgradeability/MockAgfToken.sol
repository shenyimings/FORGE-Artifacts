// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {AGFTokenV1} from '../../reward/AGFTokenV1.sol';

contract MockAgfToken is AGFTokenV1 {
  function getRevision() internal pure override returns (uint256) {
    return super.getRevision() + 1;
  }

  function _checkTransfer(address, address) internal view override {}
}
