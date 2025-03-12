// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IPrismaTreasury {
    function unallocatedTotal() external view returns (uint256);

    function allocateNewEmissions(uint id) external returns (uint256);

    function transferAllocatedTokens(address claimant, address receiver, uint256 amount) external returns (uint256);
}
