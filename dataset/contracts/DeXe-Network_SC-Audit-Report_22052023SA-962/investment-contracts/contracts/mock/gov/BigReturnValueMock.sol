// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract BigReturnValueMock {
    bool withRevert;

    function execute() external returns (bytes memory) {
        if (withRevert) {
            revert();
        } else {
            return
                hex"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";
        }
    }

    function switcher() external {
        withRevert = !withRevert;
    }
}
