// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IFundSwapErrors {
  error FundSwap__InvalidOrderSignature();
  error FundSwap__InsufficientMakerBalance();
  error FundSwap__InsufficientTakerBalance();
  error FundSwap__YouAreNotARecipient();
  error FundSwap__NotAnOwner();
  error FundSwap__OrderDoesNotExist();
  error FundSwap__OrderExpired();
  error FundSwap__OrderHaveAlreadyBeenExecuted();
  error FundSwap__MakerSellTokenAmountIsZero();
  error FundSwap__MakerBuyTokenAmountIsZero();
  error FundSwap__AmountInExceededLimit();
  error FundSwap__InvalidPath();
  error FundSwap__WithdrawalViolatesFullBackingRequirement();
  error FundSwap__InsufficientOutputAmount(uint256 minAmountOut, uint256 fillAmountOut);
  error FundSwap__TransferFeeTokensNotSupported(address unsupportedToken);
}

interface IFundSwapEvents {
  event PublicOrderCreated(
    bytes32 indexed tokenHash,
    uint256 indexed tokenId,
    address makerSellToken,
    address makerBuyToken,
    uint256 makerSellTokenAmount,
    uint256 makerBuyTokenAmount,
    address owner,
    uint256 deadline,
    uint256 creationTimestamp
  );
  event PublicOrderFilled(
    bytes32 indexed tokenHash,
    uint256 indexed tokenId,
    address makerSellToken,
    address makerBuyToken,
    address owner,
    address taker
  );
  event PublicOrderPartiallyFilled(
    bytes32 indexed tokenHash,
    uint256 indexed tokenId,
    address indexed taker,
    uint256 amountIn,
    uint256 amountOut,
    uint256 newMakerSellTokenAmount,
    uint256 newMakerBuyTokenAmount
  );
  event PublicOrderCancelled(
    bytes32 indexed tokenHash,
    uint256 indexed tokenId,
    address makerSellToken,
    address makerBuyToken,
    address owner
  );
  event PrivateOrderInvalidated(
    address indexed makerSellToken,
    uint256 makerSellTokenAmount,
    address indexed makerBuyToken,
    uint256 makerBuyTokenAmount,
    address indexed maker,
    address recipient,
    uint256 deadline,
    uint256 creationTimestamp,
    bytes32 orderHash
  );
  event PrivateOrderFilled(
    address indexed makerSellToken,
    address indexed makerBuyToken,
    address maker,
    address taker
  );
  event PluginEnabled(address indexed plugin);
  event PluginDisabled(address indexed plugin);
}
