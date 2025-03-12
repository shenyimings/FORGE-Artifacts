// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface MyNFT  {
    function createFromERC20(address sender, uint256 category) external returns (uint256);
}