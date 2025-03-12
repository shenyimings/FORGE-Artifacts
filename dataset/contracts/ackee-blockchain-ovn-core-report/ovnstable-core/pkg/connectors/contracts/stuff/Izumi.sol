// SPDX-License-Identifier: MIT
pragma solidity >=0.5 <0.9.0;

interface IMiningFixRangeBoost {

    function deposit(uint256 tokenId, uint256 nIZI) external returns (uint256 vLiquidity);

    function withdraw(uint256 tokenId, bool noReward) external;

    function collectReward(uint256 tokenId) external;
}
