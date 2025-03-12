// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.6.8;

import '../libraries/SafeMath64.sol';


contract SafeMath64Mock {
  function mul(uint64 a, uint64 b) public pure returns (uint64) {
    return SafeMath64.mul(a, b);
  }

  function div(uint64 a, uint64 b) public pure returns (uint64) {
    return SafeMath64.div(a, b);
  }

  function sub(uint64 a, uint64 b) public pure returns (uint64) {
    return SafeMath64.sub(a, b);
  }

  function add(uint64 a, uint64 b) public pure returns (uint64) {
    return SafeMath64.add(a, b);
  }
}
