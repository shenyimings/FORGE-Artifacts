// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

contract MockVPairFactory {
    function pairs(address token0, address token1) public returns (address) {
        return token0;
    }
}
