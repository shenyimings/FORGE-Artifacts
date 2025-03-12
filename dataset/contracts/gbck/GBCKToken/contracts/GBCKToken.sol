// contracts/GBCKToken.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// OpenZeppelin dependencies
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GBCKToken is ERC20, Ownable {
	uint256 private immutable _cap = 15_000_000 * 10 ** 18;
	uint256 public publicSaleStartDate;
	mapping(address => bool) public allowedTransfer;

	constructor(
		string memory _name,
		string memory _symbol,
		address _tokensReceiver
	) ERC20(_name, _symbol) {
		_transferOwnership(msg.sender);
		uint256 extraTokens = 500_000 * 10 ** 18;
		allowedTransfer[_tokensReceiver] = true;
		allowedTransfer[msg.sender] = true;
		_mint(_tokensReceiver, extraTokens);
		_mint(msg.sender, _cap - extraTokens);
	}

	/**
	 * @dev Returns the cap on the token's total supply.
	 */
	function cap() public view virtual returns (uint256) {
		return _cap;
	}

	/**
	 * @dev See {ERC20-_mint}.
	 */
	function _mint(address account, uint256 amount) internal virtual override {
		require(
			ERC20.totalSupply() + amount <= cap(),
			"GBCKToken: cap exceeded"
		);
		super._mint(account, amount);
	}

	/**
	 * @dev Allows the owner to toggle the allowedTransfer of an address.
	 * @param _address The address to toggle allowedTransfer.
	 */
	function toggleAllowedTransfer(address _address) public onlyOwner {
		allowedTransfer[_address] = !allowedTransfer[_address];
	}

	/**
	 * @dev Allows the owner to set the public sale start date.
	 * @param _publicSaleStartDate The public sale start date.
	 */
	function setPublicSaleStartDate(
		uint256 _publicSaleStartDate
	) public onlyOwner {
		require(
			_publicSaleStartDate > block.timestamp,
			"GBCKToken: invalid date"
		);
		publicSaleStartDate = _publicSaleStartDate;
	}

	/**
	 * @dev See {ERC20-_transfer}.
	 */
	function _transfer(
		address sender,
		address recipient,
		uint256 amount
	) internal virtual override {
		require(
			block.timestamp >= publicSaleStartDate || allowedTransfer[sender],
			"GBCKToken: transfer not allowed"
		);
		super._transfer(sender, recipient, amount);
	}
}
