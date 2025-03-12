// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IVault is IAccessControl {
  function WETH() external view returns (address);

  receive() external payable;

  function deposit() external payable;

  function withdraw(address payable to, uint256 amount) external;

  function depositTokens(address token, address from, uint256 amount) external;

  function withdrawTokens(address token, address to, uint256 amount) external;

  function updateThreshold(address token, uint256 amount) external;
}
