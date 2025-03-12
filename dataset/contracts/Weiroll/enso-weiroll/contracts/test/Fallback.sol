// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "../Libraries/Events.sol";

contract Fallback is Events {
    fallback(bytes calldata) external payable override returns (bytes memory) {
        if (msg.value > 0) emit LogUint(msg.value);
        if (msg.data.length > 0) emit LogBytes(msg.data);
        return abi.encode("fallback");
    }
}
