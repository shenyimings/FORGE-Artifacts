// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;
pragma abicoder v2;

interface ICollectFees {
    function collectFees(uint256 tokenId, bool returnTokensToUser) external returns (uint256 amount0, uint256 amount1);
}
