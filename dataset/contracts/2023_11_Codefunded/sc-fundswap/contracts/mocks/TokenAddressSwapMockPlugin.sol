// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { PluginBase, PluginCallsConfig } from '../plugins/PluginBase.sol';
import { PublicOrder } from '../OrderStructs.sol';

/**
 * @notice Mock plugin that is only used for testing purposes.
 */
contract TokenAddressSwapMockPlugin is PluginBase {
  function getCallsConfig() external pure override returns (PluginCallsConfig memory) {
    return
      PluginCallsConfig({
        beforeOrderCreation: true,
        afterOrderCreation: false,
        beforeOrderFill: false,
        afterOrderFill: false,
        beforeOrderCancel: false,
        afterOrderCancel: false
      });
  }

  function beforeOrderCreation(
    PublicOrder memory order
  ) external pure override returns (PublicOrder memory) {
    (order.makerSellToken, order.makerBuyToken) = (
      order.makerBuyToken,
      order.makerSellToken
    );
    return order;
  }
}
