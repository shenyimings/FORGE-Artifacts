// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

abstract contract NonZeroAddressGuard {

    modifier nonZeroAddress(address _address) {
        require(_address != address(0), "Address must be non-zero");
        _;
    }
}