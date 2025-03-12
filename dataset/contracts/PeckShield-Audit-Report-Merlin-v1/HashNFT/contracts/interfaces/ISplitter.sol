// contracts/Project.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISplitter {

    function setup(address[] memory payees, uint256[] memory shares_) external payable;
}