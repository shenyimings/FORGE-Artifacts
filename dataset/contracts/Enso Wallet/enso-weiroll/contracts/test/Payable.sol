// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.16;

contract Payable {
    function pay() external payable {}

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}
