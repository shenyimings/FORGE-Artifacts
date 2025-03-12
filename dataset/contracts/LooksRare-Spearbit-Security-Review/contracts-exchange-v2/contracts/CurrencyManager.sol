// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Interfaces
import {ICurrencyManager} from "./interfaces/ICurrencyManager.sol";

// Dependencies
import {AffiliateManager} from "./AffiliateManager.sol";

/**
 * @title CurrencyManager
 * @notice This contract manages the whitelist of valid fungible currencies.
 * @author LooksRare protocol team (ðŸ‘€,ðŸ’Ž)
 */
contract CurrencyManager is ICurrencyManager, AffiliateManager {
    /**
     * @notice It checks whether the currency is whitelisted for transacting.
     */
    mapping(address => bool) public isCurrencyWhitelisted;

    /**
     * @notice Constructor
     * @param _owner Owner address
     */
    constructor(address _owner) AffiliateManager(_owner) {}

    /**
     * @notice This function allows the owner to update the whitelist/blacklist status of a currency for transacting.
     * @param currency Currency address (address(0) for ETH)
     * @param isWhitelisted Whether the currency is whitelisted
     * @dev Only callable by owner.
     */
    function updateCurrencyWhitelistStatus(address currency, bool isWhitelisted) external onlyOwner {
        isCurrencyWhitelisted[currency] = isWhitelisted;
        emit CurrencyWhitelistStatusUpdated(currency, isWhitelisted);
    }
}
