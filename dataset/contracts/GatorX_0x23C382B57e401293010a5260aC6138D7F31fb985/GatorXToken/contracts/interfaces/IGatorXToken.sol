// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IGatorXToken {

    function getHolders() external view returns (address[] memory);
    
}
