// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Context Functions to be used instead of msg.sender and msg.data directly (see the issue with GSN meta-transactions)
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
