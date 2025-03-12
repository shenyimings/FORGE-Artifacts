// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '../OrderStructs.sol';
import '../plugins/PluginBase.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @notice Stores the addresses of plugins that should be called in certain moments
 * when performing transactions in FundSwap
 */
struct PluginsToRun {
  EnumerableSet.AddressSet beforeOrderCreation;
  EnumerableSet.AddressSet afterOrderCreation;
  EnumerableSet.AddressSet beforeOrderFill;
  EnumerableSet.AddressSet afterOrderFill;
  EnumerableSet.AddressSet beforeOrderCancel;
  EnumerableSet.AddressSet afterOrderCancel;
}

/**
 * @notice Library for managing orders
 */
library PluginLib {
  using EnumerableSet for EnumerableSet.AddressSet;

  error PluginLib__TokenAddressChangeNotAllowed();

  /**
   * @notice Stores the plugin call config so it is easy to query when performing transactions
   * @param pluginsToRun storage variable to write to
   * @param plugin new plugin that is going to be appended to the call config
   */
  function storePluginCallConfig(
    PluginsToRun storage pluginsToRun,
    PluginBase plugin
  ) internal {
    PluginCallsConfig memory pluginCallsConfig = plugin.getCallsConfig();
    if (pluginCallsConfig.beforeOrderCreation) {
      pluginsToRun.beforeOrderCreation.add(address(plugin));
    }
    if (pluginCallsConfig.afterOrderCreation) {
      pluginsToRun.afterOrderCreation.add(address(plugin));
    }
    if (pluginCallsConfig.beforeOrderFill) {
      pluginsToRun.beforeOrderFill.add(address(plugin));
    }
    if (pluginCallsConfig.afterOrderFill) {
      pluginsToRun.afterOrderFill.add(address(plugin));
    }
    if (pluginCallsConfig.beforeOrderCancel) {
      pluginsToRun.beforeOrderCancel.add(address(plugin));
    }
    if (pluginCallsConfig.afterOrderCancel) {
      pluginsToRun.afterOrderCancel.add(address(plugin));
    }
  }

  /**
   * @notice Removes the plugin call config so it is no longer going to be called when executing a transaction
   * @param pluginsToRun storage variable to write to
   * @param plugin old plugin that is going to be removed from the call config
   */
  function removePluginCallConfig(
    PluginsToRun storage pluginsToRun,
    PluginBase plugin
  ) internal {
    PluginCallsConfig memory pluginCallsConfig = plugin.getCallsConfig();
    if (pluginCallsConfig.beforeOrderCreation) {
      pluginsToRun.beforeOrderCreation.remove(address(plugin));
    }
    if (pluginCallsConfig.afterOrderCreation) {
      pluginsToRun.afterOrderCreation.remove(address(plugin));
    }
    if (pluginCallsConfig.beforeOrderFill) {
      pluginsToRun.beforeOrderFill.remove(address(plugin));
    }
    if (pluginCallsConfig.afterOrderFill) {
      pluginsToRun.afterOrderFill.remove(address(plugin));
    }
    if (pluginCallsConfig.beforeOrderCancel) {
      pluginsToRun.beforeOrderCancel.remove(address(plugin));
    }
    if (pluginCallsConfig.afterOrderCancel) {
      pluginsToRun.afterOrderCancel.remove(address(plugin));
    }
  }

  /**
   * @notice Checks if plugins performed any changes to the order that are not allowed.
   * @param initialMakerSellToken initial maker sell token address from a given order
   * @param initialMakerBuyToken initial maker buy token address from a given order
   * @param finalMakerSellToken final maker sell token address after order has been modified by a plugin
   * @param finalMakerBuyToken final maker buy token address after order has been modified by a plugin
   */
  function _checkPluginChanges(
    address initialMakerSellToken,
    address initialMakerBuyToken,
    address finalMakerSellToken,
    address finalMakerBuyToken
  ) private pure {
    if (
      initialMakerSellToken != finalMakerSellToken ||
      initialMakerBuyToken != finalMakerBuyToken
    ) {
      revert PluginLib__TokenAddressChangeNotAllowed();
    }
  }

  /**
   * @notice Calls all plugins that have a `beforeOrderCreation` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runBeforeOrderCreation(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.beforeOrderCreation.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.beforeOrderCreation.at(i)).beforeOrderCreation(
        result
      );
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }

  /**
   * @notice Calls all plugins that have a `afterOrderCreation` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runAfterOrderCreation(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.afterOrderCreation.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.afterOrderCreation.at(i)).afterOrderCreation(
        result
      );
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }

  /**
   * @notice Calls all plugins that have a `runBeforeOrderFill` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runBeforeOrderFill(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.beforeOrderFill.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.beforeOrderFill.at(i)).beforeOrderFill(result);
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }

  /**
   * @notice Calls all plugins that have a `runAfterOrderFill` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runAfterOrderFill(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.afterOrderFill.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.afterOrderFill.at(i)).afterOrderFill(result);
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }

  /**
   * @notice Calls all plugins that have a `runBeforeOrderCancel` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runBeforeOrderCancel(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.beforeOrderCancel.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.beforeOrderCancel.at(i)).beforeOrderCancel(result);
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }

  /**
   * @notice Calls all plugins that have a `runAfterOrderCancel` hook enabled. Result of a hook
   * is passed to the next hook in a line.
   * @param pluginsToRun config of plugins to run
   * @param order order that is currently being evaluated
   */
  function runAfterOrderCancel(
    PluginsToRun storage pluginsToRun,
    PublicOrder memory order
  ) internal returns (PublicOrder memory result) {
    (address initalMakerSellToken, address initialMakerBuyToken) = (
      order.makerSellToken,
      order.makerBuyToken
    );
    result = order;
    uint256 amountOfPlugins = pluginsToRun.afterOrderCancel.length();
    for (uint i = 0; i < amountOfPlugins; ++i) {
      result = PluginBase(pluginsToRun.afterOrderCancel.at(i)).afterOrderCancel(result);
      _checkPluginChanges(
        initalMakerSellToken,
        initialMakerBuyToken,
        result.makerSellToken,
        result.makerBuyToken
      );
    }
  }
}
