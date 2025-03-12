// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title ICurrencyManager
 * @author LooksRare protocol team (👀,💎)
 */
interface ICurrencyManager {
    /**
     * @notice It is emitted if the status of a currency in the whitelist is updated.
     * @param currency Currency address (address(0) = ETH)
     * @param isWhitelisted Whether the currency is whitelisted
     */
    event CurrencyWhitelistStatusUpdated(address currency, bool isWhitelisted);
}
