//SPDX-License-Identifier: Unlicensed

pragma solidity =0.6.12;

contract MockTimeLockTesting {

    address public pendingAdmin;

    constructor() public { 
    }

    function setPendingAdmin(address pendingAdmin_) public {
        pendingAdmin = pendingAdmin_;
    }
}