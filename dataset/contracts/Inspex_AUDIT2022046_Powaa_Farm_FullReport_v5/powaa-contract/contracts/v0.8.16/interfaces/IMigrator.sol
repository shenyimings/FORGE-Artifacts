// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

interface IMigrator {
  function execute(bytes calldata data) external;

  function whitelistTokenVault(address tokenVault, bool isOk) external;
}
