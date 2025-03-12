// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IVaultRateProvider
 * @author Kresko
 * @notice Minimal exchange rate interface for vaults.
 */
interface IVaultRateProvider {
    /**
     * @notice Gets the exchange rate of one vault share to USD.
     * @return uint256 The current exchange rate of the vault share in 18 decimals precision.
     */
    function exchangeRate() external view returns (uint256);
}
