// SPDX-License-Identifier: UNLICENSED
// IWrappedToken.sol: Interface for wrapped Terra assets
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IShuttleAsset is IERC20 {
  function burn(uint256 amount, bytes32 to) external;
}
