// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract ForwarderMock {
    using Address for address;

    /// @notice Forward without appending a sender address to the calldata, so that msg.data.length < 24 (non-EIP-2771)
    function non2771Forward(address target, bytes calldata data) external payable {
        target.functionCallWithValue(data, msg.value);
    }

    /// @notice Forward while appending a sender address to the calldata (EIP-2771-compatible)
    function forward(address from, address target, bytes calldata data) external payable {
        target.functionCallWithValue(abi.encodePacked(data, from), msg.value);
    }
}
