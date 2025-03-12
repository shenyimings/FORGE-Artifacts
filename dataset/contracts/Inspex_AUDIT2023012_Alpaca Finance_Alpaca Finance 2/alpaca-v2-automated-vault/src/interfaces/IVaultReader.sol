// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IVaultReader {
  struct VaultSummary {
    uint256 token0price; // price in e18
    uint256 token1price; // price in e18
    uint256 token0Undeployed;
    uint256 token1Undeployed;
    uint256 token0Farmed;
    uint256 token1Farmed;
    uint256 token0Debt;
    uint256 token1Debt;
    uint256 lowerPrice; // quote token0/token1
    uint256 upperPrice; // quote token0/token1
  }

  struct TokenAmount {
    address token;
    uint256 amount;
  }

  function getVaultSummary(address _vaultToken) external view returns (VaultSummary memory);

  function getVaultSharePrice(address _vaultToken)
    external
    view
    returns (uint256 _sharePrice, uint256 _sharePriceWithManagementFee);

  function getPendingRewards(address _vaultToken) external view returns (TokenAmount[] memory pendingRewards);
}
