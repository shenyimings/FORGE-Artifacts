// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LucidaoGovernanceReserve is Ownable {
	using SafeERC20 for IERC20;

	uint32 public immutable amountForLiquidity;
	address public immutable liquidityVault;
	bool public canWithdrawForLiquidity;
	ERC20 public liquidityToken;

	modifier onlyOnce() {
		require(canWithdrawForLiquidity, "Function already executed");
		_;
	}

	constructor(ERC20 _liquidityToken, address _liquidityVault, uint32 _amountForLiquidity) {
		require(_liquidityVault != address(0), "_liquidityVault is the zero address");

		liquidityVault = _liquidityVault;
		liquidityToken = _liquidityToken;
		amountForLiquidity = _amountForLiquidity;
		canWithdrawForLiquidity = true;
	}

	function approveToken(IERC20 token, uint256 weiAmount, address spender) external onlyOwner {
		token.safeApprove(spender, weiAmount);
	}

	function increaseAllowanceToken(IERC20 token, uint256 weiAmount, address spender) external onlyOwner {
		token.safeIncreaseAllowance(spender, weiAmount);
	}

	function decreaseAllowanceToken(IERC20 token, uint256 weiAmount, address spender) external onlyOwner {
		token.safeDecreaseAllowance(spender, weiAmount);
	}

	function withdrawForLiquidity() external onlyOnce {
		canWithdrawForLiquidity = false;
		uint256 transferValue = amountForLiquidity * 10**liquidityToken.decimals();
		IERC20(liquidityToken).safeTransfer(liquidityVault, transferValue);
	}
}
