// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { PublicOrder } from '../OrderStructs.sol';

/**
 * @notice Holds information about which hooks a given plugin implement
 */
struct PluginCallsConfig {
  bool beforeOrderCreation;
  bool afterOrderCreation;
  bool beforeOrderFill;
  bool afterOrderFill;
  bool beforeOrderCancel;
  bool afterOrderCancel;
}

/**
 * @notice interface for a FundSwap plugin. It allows to specify a custom logic to run when a significant event
 * occurs during the FundSwap contract lifecycle, i.e. order creation, order fill and order cancellation.
 */
abstract contract PluginBase {
  /**
   * @notice allows to run a custom logic when enabling the plugin. It is a noop if not overriden in a plugin.
   * @param data custom data that is in form of bytes so it can be abi decoded to a custom format
   */
  function enable(bytes memory data) external virtual {}

  /**
   * @notice allows to run a custom logic when disabling the plugin. It is a noop if not overriden in a plugin.
   * @param data custom data that is in form of bytes so it can be abi decoded to a custom format
   */
  function disable(bytes memory data) external virtual {}

  /**
   * @notice returns the plugin call config to describe which hooks the plugin implements. Overriding this function
   * is mandatory.
   */
  function getCallsConfig() external view virtual returns (PluginCallsConfig memory);

  /**
   * @notice allows to run a custom logic before the order is created. It is a noop if not overriden in a plugin.
   */
  function beforeOrderCreation(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }

  /**
   * @notice allows to run a custom logic after the order is created. It is a noop if not overriden in a plugin.
   */
  function afterOrderCreation(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }

  /**
   * @notice allows to run a custom logic before the order is filled. It is a noop if not overriden in a plugin.
   */
  function beforeOrderFill(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }

  /**
   * @notice allows to run a custom logic after the order is filled. It is a noop if not overriden in a plugin.
   */
  function afterOrderFill(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }

  /**
   * @notice allows to run a custom logic before the order is canceled. It is a noop if not overriden in a plugin.
   */
  function beforeOrderCancel(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }

  /**
   * @notice allows to run a custom logic after the order is canceled. It is a noop if not overriden in a plugin.
   */
  function afterOrderCancel(
    PublicOrder memory order
  ) external virtual returns (PublicOrder memory) {
    return order;
  }
}
