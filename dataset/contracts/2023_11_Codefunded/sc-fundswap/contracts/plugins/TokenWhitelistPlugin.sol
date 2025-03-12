// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { PluginBase, PluginCallsConfig } from './PluginBase.sol';
import { Ownable2Step, Ownable } from '@openzeppelin/contracts/access/Ownable2Step.sol';
import { EnumerableSet } from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import { PublicOrder } from '../OrderStructs.sol';

/**
 * @notice Allows to add and remove tokens from a whitelist. It reverts when a user wants to create or fill
 * an order that contains a token that is not whitelisted. Order cancellation can always happen so user can still
 * cancel an order even if one of the order's tokens has been removed from the whitelist in the meantime.
 */
contract TokenWhitelistPlugin is PluginBase, Ownable2Step {
  error TokenWhitelistPlugin__TokenNotWhitelisted(address token);

  using EnumerableSet for EnumerableSet.AddressSet;

  event TokenAddedToWhitelist(address token);
  event TokenRemovedFromWhitelist(address token);

  EnumerableSet.AddressSet private whitelistedTokens;

  constructor() Ownable(_msgSender()) {}

  // ======== PLUGIN LOGIC ========

  function getCallsConfig() external pure override returns (PluginCallsConfig memory) {
    return
      PluginCallsConfig({
        beforeOrderCreation: true,
        afterOrderCreation: false,
        beforeOrderFill: true,
        afterOrderFill: false,
        beforeOrderCancel: false,
        afterOrderCancel: false
      });
  }

  function beforeOrderCreation(
    PublicOrder memory order
  ) external view override returns (PublicOrder memory) {
    requireTokensWhitelisted(order);
    return order;
  }

  function beforeOrderFill(
    PublicOrder memory order
  ) external view override returns (PublicOrder memory) {
    requireTokensWhitelisted(order);
    return order;
  }

  // ======== DOMAIN LOGIC ========

  /**
   * @notice Checks if a token is whitelisted.
   * @param token token address to check
   * @return true if the token is whitelisted, false otherwise
   */
  function isTokenWhtelisted(address token) public view returns (bool) {
    return whitelistedTokens.contains(token);
  }

  /**
   * @notice Adds a token to the whitelist. If the token is already whitelisted, it does nothing.
   * @param token token address to add to the whitelist
   */
  function addTokenToWhitelist(address token) public onlyOwner {
    if (whitelistedTokens.add(token)) {
      emit TokenAddedToWhitelist(token);
    }
  }

  /**
   * @notice Removes a token from the whitelist. If the token is not whitelisted, it does nothing.
   * @param token token address to remove from the whitelist
   */
  function removeTokenFromWhitelist(address token) public onlyOwner {
    if (whitelistedTokens.remove(token)) {
      emit TokenRemovedFromWhitelist(token);
    }
  }

  /**
   * @notice Returns a list of whitelisted tokens.
   * @return list of whitelisted tokens
   */
  function getWhitelistedTokens() public view returns (address[] memory) {
    return whitelistedTokens.values();
  }

  /**
   * @notice Checks if tokens from order are whitelisted.
   * @param order order with tokens to check
   */
  function requireTokensWhitelisted(PublicOrder memory order) internal view {
    if (!isTokenWhtelisted(order.makerSellToken)) {
      revert TokenWhitelistPlugin__TokenNotWhitelisted(order.makerSellToken);
    }
    if (!isTokenWhtelisted(order.makerBuyToken)) {
      revert TokenWhitelistPlugin__TokenNotWhitelisted(order.makerBuyToken);
    }
  }
}
