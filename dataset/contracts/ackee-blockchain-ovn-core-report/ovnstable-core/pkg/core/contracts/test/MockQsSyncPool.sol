// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


contract MockQsSyncPool {

    // --- logic

    function sync() external {
        // need just detect that method was called and could be
        // made by revert usage in tests
        revert("MockQsSyncPool.sync() called");
    }

}
