// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IPoolHelper {
    function getSlippage(uint256 cov, uint256 slippageA, uint256 slippageN, uint256 slippageK) external pure returns (uint256);
}