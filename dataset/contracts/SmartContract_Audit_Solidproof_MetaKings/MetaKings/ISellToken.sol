// SPDX-License-Identifier: MIT
/*
█▀▄▀█ █▀▀ ▀█▀ ▄▀█ █▄▀ █ █▄░█ █▀▀ █▀
█░▀░█ ██▄ ░█░ █▀█ █░█ █ █░▀█ █▄█ ▄█

Welcome to MetaKings
> 100%Unmintable contract
> 100%Unruggable contract
> Website:https://Metakings.ai
> Telegram:https://t.me/metakings
*/
pragma solidity 0.6.12;

/**
 * @dev Interface of the SellToken standard as defined in the EIP.
 * From https://github.com/OpenZeppelin/openzeppelin-contracts
 */
interface ISellToken {
  /**
   * @dev Returns the amount of tokens in existence.
   */
  function receivedAmount(address recipient) external view returns (uint256);

}