// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {DepositToken} from '../../protocol/tokenization/DepositToken.sol';

contract MockDepositToken is DepositToken {
  function getRevision() internal pure override returns (uint256) {
    return super.getRevision() + 1;
  }
}
