// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '../OrderStructs.sol';

/**
 * @notice Library for managing orders
 */
library OrderLib {
  using Math for uint256;

  error OrderLib__InvalidOrderType();

  /**
   * @notice Checks if the fill request for a given order is partial
   * @param request order fill request to check
   * @param order underlying order
   */
  function isFillRequestPartial(
    OrderFillRequest memory request,
    PublicOrder memory order
  ) internal pure returns (bool isPartial) {
    return request.amountIn < order.makerBuyTokenAmount;
  }

  /**
   * @notice Calculates the amount of tokens after a partial fill of a given order
   * @param request order fill request
   * @param order underlying order
   * @return orderMakerBuyTokenAmount the amount of tokens that maker can still get after the fill
   * for the remaining sell tokens on the order
   * @return orderMakerSellTokenAmount the amount of tokens that maker still wants to sell after the fill
   * @return inputAmount the amount of tokens needed to fill the order
   * @return outputAmount the amount of tokens received from the fill
   */
  function calculateOrderAmountsAfterFill(
    OrderFillRequest memory request,
    PublicOrder memory order
  )
    internal
    pure
    returns (
      uint256 orderMakerBuyTokenAmount,
      uint256 orderMakerSellTokenAmount,
      uint256 inputAmount,
      uint256 outputAmount
    )
  {
    uint256 makerBuyTokenAmountBeforeSwap = order.makerBuyTokenAmount;
    orderMakerBuyTokenAmount = order.makerBuyTokenAmount - request.amountIn;
    uint256 makerSellTokenAmountBeforeSwap = order.makerSellTokenAmount;
    orderMakerSellTokenAmount = order.makerSellTokenAmount.mulDiv(
      orderMakerBuyTokenAmount,
      makerBuyTokenAmountBeforeSwap,
      Math.Rounding.Ceil
    );
    inputAmount = request.amountIn;
    outputAmount = makerSellTokenAmountBeforeSwap - orderMakerSellTokenAmount;

    return (
      orderMakerBuyTokenAmount,
      orderMakerSellTokenAmount,
      inputAmount,
      outputAmount
    );
  }
}
