// SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

contract Echo {
    function echo() external view returns (address) {
        return msg.sender;
    }
}
