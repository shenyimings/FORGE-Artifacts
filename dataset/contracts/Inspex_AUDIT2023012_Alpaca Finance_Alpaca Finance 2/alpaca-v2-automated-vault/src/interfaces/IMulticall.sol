// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

interface IMulticall {
  function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
