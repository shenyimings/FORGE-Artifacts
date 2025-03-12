// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library UintLib {

    /// Convert uint (uint256) to address format
    /// @param _val uint
    /// @return uint
    function toAddress(uint _val) internal pure returns(address) {
        return address(uint160(_val));
    }
}
