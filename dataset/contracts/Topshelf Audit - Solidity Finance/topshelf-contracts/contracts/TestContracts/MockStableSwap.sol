// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;


contract MockStableSwap {

    function get_virtual_price() external pure returns (uint256) {
      return 1; // comment to rebuild
    }
}
