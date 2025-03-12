// SPDX-License-Identifier: MIT
pragma solidity 0.6.9;

interface ISmartWalletFactory {

  function getSmartWallet(
    address
  ) external returns (address);

}
