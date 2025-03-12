// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStETH {
    // --- Function ---
    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);

    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);
}
