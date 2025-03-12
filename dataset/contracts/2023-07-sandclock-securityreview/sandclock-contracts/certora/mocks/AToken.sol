// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.13;

import {IPool} from "lib/aave-v3-core/contracts/interfaces/IPool.sol";
import {IAaveIncentivesController} from "lib/aave-v3-core/contracts/interfaces/IAaveIncentivesController.sol";
import {IAToken} from "lib/aave-v3-core/contracts/interfaces/IAToken.sol";
import {IERC20} from 'lib/aave-v3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol';

contract AToken is IAToken {

  address public underlying;

  mapping(address=>uint256) _balances;

  function mint(
    address caller,
    address onBehalfOf,
    uint256 amount,
    uint256 index
  ) external returns (bool) {
    _balances[onBehalfOf] += amount;
    return true;
  }

  function burn(
    address from,
    address receiverOfUnderlying,
    uint256 amount,
    uint256 index
  ) external {
    _balances[from] -= amount;
    if (receiverOfUnderlying != address(this)) {
      IERC20(underlying).transfer(receiverOfUnderlying, amount);
    }
  }

  function mintToTreasury(uint256 amount, uint256 index) external {}

  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) external {}

  function transferUnderlyingTo(address target, uint256 amount) external {
    IERC20(underlying).transfer(target, amount);
  }

  function handleRepayment(
    address user,
    address onBehalfOf,
    uint256 amount
  ) external {}

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {}

  function UNDERLYING_ASSET_ADDRESS() external view returns (address) {
    return underlying;
  }

  function RESERVE_TREASURY_ADDRESS() external view returns (address) {}

  function DOMAIN_SEPARATOR() external view returns (bytes32) {}

  function nonces(address owner) external view returns (uint256) {}

  function rescueTokens(
    address token,
    address to,
    uint256 amount
  ) external {}

    function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool) {}

    function initialize(
    IPool pool,
    address treasury,
    address underlyingAsset,
    IAaveIncentivesController incentivesController,
    uint8 aTokenDecimals,
    string calldata aTokenName,
    string calldata aTokenSymbol,
    bytes calldata params
  ) external {}

  function allowance(address owner, address spender) external view returns (uint256) {}

  function approve(address spender, uint256 amount) external returns (bool) {}

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function getPreviousIndex(address user) external view returns (uint256) {}

  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256) {}

  function scaledBalanceOf(address user) external view returns (uint256) {}

  function scaledTotalSupply() external view returns (uint256) {}

  function totalSupply() external view returns (uint256) {}

  function transfer(address recipient, uint256 amount) external returns (bool) {}
}
