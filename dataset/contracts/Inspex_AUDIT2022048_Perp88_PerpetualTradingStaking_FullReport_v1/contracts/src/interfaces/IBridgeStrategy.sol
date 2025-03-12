// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IBridgeStrategy {
  function execute(
    address caller,
    uint256 destinationChainId,
    address tokenRecipient,
    uint256 amount,
    bytes memory payload
  ) external payable;
}
