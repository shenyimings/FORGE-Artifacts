// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.16;

contract Events {
    event LogBytes(bytes message);
    event LogAddress(address message);
    event LogString(string message);
    event LogBytes32(bytes32 message);
    event LogUint(uint256 message);

    function logBytes(bytes calldata message) external {
        emit LogBytes(message);
    }

    function logAddress(address message) external {
        emit LogAddress(message);
    }

    function logString(string calldata message) external {
        emit LogString(message);
    }

    function logBytes32(bytes32 message) external {
        emit LogBytes32(message);
    }

    function logUint(uint256 message) external {
        emit LogUint(message);
    }

    fallback() external payable virtual {
        if (msg.value > 0) emit LogUint(msg.value);
        if (msg.data.length  > 0) emit LogBytes(msg.data);
    }

    function fallback(bytes calldata data) external payable virtual {
        if (msg.value > 0) emit LogUint(msg.value);
        if (data.length > 0) emit LogBytes(data);
    }
}
