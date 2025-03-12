// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StrategyInterface } from "../interfaces/StrategyInterface.sol";
import { IVault } from "../apis/alpaca/IVault.sol";

contract AlpacaVaultFarmStrategy is StrategyInterface {
  address public token;
  IVault public vault;
  address public pool;

  error NotWhitelistedPool();

  /// @dev A modifier that checks if the sender is the whitelisted pool. If not, it reverts.
  modifier onlyPool() {
    if (msg.sender != pool) {
      revert NotWhitelistedPool();
    }
    _;
  }

  constructor(
    address _token,
    address _vault,
    address _pool
  ) {
    token = _token;
    pool = _pool;

    vault = IVault(_vault);

    IERC20(token).approve(address(vault), type(uint256).max);
  }

  /// @dev Calculating the value of the share.
  /// @param share input share to convert to value
  /// @return value value of the share.
  function _shareToValue(uint256 share) internal view returns (uint256) {
    if (vault.totalSupply() == 0) return 0;
    return (share * (vault.totalToken())) / (vault.totalSupply());
  }

  /// @dev Calculating the share of the token holder.
  /// @param value input value to convert to share
  /// @return share share of the value.
  function _valueToShare(uint256 value) internal view returns (uint256) {
    if (vault.totalToken() == 0) return 0;
    return (value * vault.totalSupply()) / vault.totalToken();
  }

  /// @dev Depositing the amount of tokens into the vault.
  /// @param amount amount to be deposit
  function run(uint256 amount) external onlyPool {
    uint256 availableAmount = IERC20(token).balanceOf(address(this));
    if (amount > availableAmount)
      revert("AlpacaFarmStrategy: Insufficient amount to deposit");
    // Deposit funds into vault
    vault.deposit(amount);
  }

  /// @dev Rounding the share to the nearest whole number.
  /// @param amount amount to round
  /// @return share share of the amount after rounded.
  function _roundedValueToShare(uint256 amount)
    internal
    view
    returns (uint256)
  {
    uint256 share = _valueToShare(amount);
    uint256 convertedAmount = _shareToValue(share);
    // If calculated share converting back to value is less than the actual value, increase 1 WEI of share
    if (convertedAmount < amount) {
      return share + 1;
    }
    return share;
  }

  /// @dev Realize the profit or loss from given principle
  /// @param principle to calculate profit/loss with
  /// @return amountDelta profit or loss realized.
  function realized(uint256 principle)
    external
    onlyPool
    returns (int256 amountDelta)
  {
    (bool isProfit, uint256 amount) = getStrategyDelta(principle);
    if (isProfit) {
      vault.withdraw(_roundedValueToShare(amount));
      uint256 balance = IERC20(token).balanceOf(address(this));
      IERC20(token).transfer(msg.sender, balance);
      return int256(balance);
    } else {
      return -int256(amount);
    }
  }

  /// @dev Withdrawing the amount of tokens from the vault.
  /// @param amount amount to be withdrawn
  /// @return actualAmount actual amount that could be withdrawn
  function withdraw(uint256 amount)
    external
    onlyPool
    returns (uint256 actualAmount)
  {
    vault.withdraw(_roundedValueToShare(amount));
    actualAmount = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(msg.sender, actualAmount);

    return actualAmount;
  }

  /// @dev Withdraw all token after calculating the profit/loss of the strategy.
  /// @param principle to calculate profit/loss with
  /// @return amountDelta profit or loss realized.
  function exit(uint256 principle)
    external
    onlyPool
    returns (int256 amountDelta)
  {
    // Calculate profit/losee
    (bool isProfit, uint256 uamountDelta) = getStrategyDelta(principle);

    // Withdraw all funds from vault
    vault.withdraw(vault.balanceOf(address(this)));

    // Transfer what left back to pool
    IERC20(token).transfer(pool, IERC20(token).balanceOf(address(this)));

    return isProfit ? int256(uamountDelta) : -int256(uamountDelta);
  }

  /// @dev Calculating the profit/loss of the strategy.
  /// @param principle to calculate profit/loss with
  /// @return isProfit boolean to determine whether the strategy is profit
  /// @return amountDelta profit or loss realized.
  function getStrategyDelta(uint256 principle)
    public
    view
    returns (bool isProfit, uint256 amountDelta)
  {
    uint256 value = _shareToValue(vault.balanceOf(address(this)));
    if (value > principle) {
      return (true, value - principle);
    } else {
      return (false, principle - value);
    }
  }
}
