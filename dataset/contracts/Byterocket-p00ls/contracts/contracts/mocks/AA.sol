// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";

contract AA {
    event Call(address sender, uint256 value, bytes data);

    fallback() external payable {
        emit Call(msg.sender, msg.value, msg.data);
    }

    function __forward(address target, uint256 value, bytes calldata data) external payable {
        Address.functionCallWithValue(target, data, value);
    }
}