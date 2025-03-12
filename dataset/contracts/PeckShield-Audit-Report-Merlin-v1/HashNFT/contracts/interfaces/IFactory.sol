// contracts/Project.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactory {

    function createSplitter(uint256) external returns(address);

    function getSplitterAddress(address factory, uint256 idx) external view returns(address);

}
