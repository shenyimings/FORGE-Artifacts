// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract MockOpenVault {
    function withdrawEnabled() external pure returns (bool) {
        return false;
    }
}
