// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./openzeppelin_v2_5_0/Roles.sol";


contract LucidaoSale is Context, ReentrancyGuard {
	using SafeERC20 for IERC20;
	using Roles for Roles.Role;

	IERC20 public immutable token;
	IERC20 public immutable buyToken;

	address public immutable treasuryWallet;
	uint256 public immutable rate;
	uint256 public weiRaised;
	uint256 public tokensSold;

	mapping(address => uint256) public contributions;
	uint256 public immutable cap;
	uint256 public immutable tokensForSale;

	uint256 public immutable openingTime;
	uint256 public immutable closingTime;

	Roles.Role internal _whitelisted;
	mapping(address => uint256) private _balances;

	event TokensPurchased(address indexed purchaser, uint256 value, uint256 amount);

	modifier onlyWhileOpen() {
		require(isOpen(), "Sale not open");
		_;
	}

	modifier onlyWhileClosed() {
		require(isClosed(), "Sale not finished yet");
		_;
	}

	modifier onlyWhitelisted() {
		require(isWhitelisted(_msgSender()), "Beneficiary isn't whitelisted");
		_;
	}

	constructor(
		uint256 _rate,
		uint256 _cap,
		address _treasuryWallet,
		IERC20 _token,
		IERC20 _buyToken,
		uint256 _openingTime,
		uint256 _closingTime,
		uint256 _tokensForSale,
		address[] memory _whitelistedAddresses
	) {
		require(_rate > 0, "Rate is 0");
		require(_treasuryWallet != address(0), "treasuryWallet is the zero address");
		require(address(_token) != address(0), "Token is the zero address");
		require(_openingTime >= block.timestamp, "Opening time is before current time");
		require(_closingTime > _openingTime, "Opening time is not before closing time");

		rate = _rate;
		cap = _cap;
		treasuryWallet = _treasuryWallet;
		token = _token;
		buyToken = _buyToken;
		openingTime = _openingTime;
		closingTime = _closingTime;
		tokensForSale = _tokensForSale;

		for (uint256 i = 0; i < _whitelistedAddresses.length; i++) {
			_whitelisted.add(_whitelistedAddresses[i]);
		}
	}

	function buyTokens(uint256 weiAmount) external nonReentrant onlyWhileOpen onlyWhitelisted {
		address beneficiary = _msgSender();
		require(weiAmount != 0, "Buy amount is 0");
		require(contributions[beneficiary] + weiAmount <= cap, "Beneficiary's cap exceeded");

		uint256 tokens = weiAmount * rate;
		tokensSold += tokens;
		require(tokensSold <= tokensForSale, "Buy amount too high");

		contributions[beneficiary] += weiAmount;
		weiRaised += weiAmount;
		_balances[beneficiary] += tokens;

		buyToken.safeTransferFrom(beneficiary, treasuryWallet, weiAmount);

		emit TokensPurchased(beneficiary, weiAmount, tokens);
	}

	function isBeforeOpen() public view returns (bool) {
		return block.timestamp < openingTime;
	}

	function isOpen() public view returns (bool) {
		return block.timestamp >= openingTime && block.timestamp <= closingTime;
	}

	function isClosed() public view returns (bool) {
		return block.timestamp > closingTime;
	}

	function isWhitelisted(address _beneficiary) public view returns (bool) {
		return _whitelisted.has(_beneficiary);
	}

	function balanceOf(address account) external view returns (uint256) {
		return _balances[account];
	}

	function withdrawTokens() external onlyWhileClosed {
		address beneficiary = _msgSender();
		uint256 amount = _balances[beneficiary];
		require(amount > 0, "Beneficiary is not due any tokens");
		_balances[beneficiary] = 0;
		token.safeTransfer(beneficiary, amount);
	}
}
