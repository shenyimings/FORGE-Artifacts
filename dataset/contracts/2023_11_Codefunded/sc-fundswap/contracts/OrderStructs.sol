// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 * @notice Holds the data for a private order. Private order means that it is not stored on chain. The maker can pass the
 * order off-chain to the recipient or publish it publicly. The recipient can then fill the order by passing the order
 * to the smart contract.
 * @param maker the address of the maker of the order
 * @param makerSellToken the address of the token being sold by the maker
 * @param makerBuyToken the address of the token that maker wants to receive
 * @param makerSellTokenAmount the amount of the token being sold by the maker
 * @param makerBuyTokenAmount the amount of the token that maker wants to receive
 * @param recipient the address of the recipient of the order. Can be address 0 if order can be filled by anyone
 * @param deadline the deadline of the order. Can be 0 if order should not expire
 * @param creationTimestamp the timestamp when the order was created. It is used to differentiate orders with the same
 * parameters (functions as a nonce)
 */
struct PrivateOrder {
  address maker;
  address makerSellToken;
  address makerBuyToken;
  uint256 makerSellTokenAmount;
  uint256 makerBuyTokenAmount;
  address recipient;
  uint256 deadline;
  uint256 creationTimestamp;
}

/**
 * @notice Holds the data for a public order that is stored on chain.
 * @param makerSellToken the address of the token being sold by the maker
 * @param makerBuyToken the address of the token that maker wants to receive
 * @param makerSellTokenAmount the amount of the token being sold by the maker
 * @param makerBuyTokenAmount the amount of the token that maker wants to receive
 * @param deadline the deadline of the order. Can be 0 if order should not expire
 * @param creationTimestamp the timestamp when the order was created. It is used to differentiate orders with the same
 * parameters (functions as a nonce)
 */
struct PublicOrder {
  address makerSellToken;
  address makerBuyToken;
  uint256 makerSellTokenAmount;
  uint256 makerBuyTokenAmount;
  uint256 deadline;
  uint256 creationTimestamp;
}

/**
 * @notice Helper struct that is used to represent a market order request. It describes a request
 * of a user to spend a certain amount of tokens.
 * @param orderHash the hash of the order to fill
 * @param amountIn the amount of tokens to spend
 * @param minAmountOut the minimum amount of tokens that should be received from the swap
 */
struct OrderFillRequest {
  bytes32 orderHash;
  uint256 amountIn;
  uint256 minAmountOut;
}

/**
 * @notice Helper struct that is used to represent the result of a swap.
 * @param outputToken the address of the token that was received from the swap
 * @param outputAmount the amount of the output token that was received from the swap
 * @param inputToken the address of the token that was spent for the swap
 * @param inputAmount the amount of the input token that was spent for the swap
 */
struct SwapResult {
  address outputToken;
  uint256 outputAmount;
  address inputToken;
  uint256 inputAmount;
}
