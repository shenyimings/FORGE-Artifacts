// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWrappedAsset is IERC20 {
  event Burn(address indexed _sender, bytes32 indexed _to, uint256 amount);

  function burn(uint256 amount, bytes32 to) external;
}
