// UstxDex.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./IERC20.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./AdminRole.sol";


/// @title Up Stable Token eXperiment DEX
/// @author USTX Team
/// @dev This contract implements the DEX functionality for the USTX token.
contract CTN is ReentrancyGuard, AdminRole {

	/***********************************|
	|        Variables && Events        |
	|__________________________________*/

	//Variables
	uint256 private _decimals;			// 6
	address private _sourceAddr;	    //Launchpad team address

	IERC20 Tusdt;						// address of the reserve token USDT

	using SafeMath for uint256;

	/**
	* @dev Constructor
	*
	* @param reserveTokenAddr contract address of the reserve token (USDT)
	*/
	constructor (address reserveTokenAddr)
	AdminRole(1)        //at least two administrsators always in charge
	public {
		require(reserveTokenAddr != address(0), "Invalid contract address");
		Tusdt = IERC20(reserveTokenAddr);
		_sourceAddr = _msgSender();
		_decimals = 6;
	}

	/***********************************|
	|        Exchange Functions         |
	|__________________________________*/

	/**
	* @dev Public function to get tokens during CTN
	* @param amount number of usdt to get
	*
	* @return number of tokens bought
	*/
	function  getCTNTokenInput(uint256 amount)  public returns (uint256)  {
		require(amount>0,"Amount must be more that zero");
		return _getTokens(amount, _msgSender());
	}

	/**
	* @dev Private function to buy tokens during launchpad with exact input in USDT
	*
	*/
	function _getTokens(uint256 amount, address buyer) private nonReentrant returns (uint256) {
		Tusdt.transferFrom(_sourceAddr, buyer, amount);     //send USDT
		return amount;
	}

	/**************************************|
	|     Getter and Setter Functions      |
	|_____________________________________*/

	/**
	* @dev Function to set USDT address (only admin)
	* @param reserveAddress address of the reserve token contract
	*/
	function setReserveTokenAddr(address reserveAddress) public onlyAdmin {
		require(reserveAddress != address(0), "INVALID_ADDRESS");
		Tusdt = IERC20(reserveAddress);
	}

	/**
	* @dev Function to get the address of the reserve token contract
	* @return Address of USDT
	*
	*/
	function getReserveAddress() public view returns (address) {
		return address(Tusdt);
	}

	/**
	* @dev Set source address (only admin)
	* @param source address for collecting fees
	*/
	function setSourceAddress(address source) public onlyAdmin {
		require(source != address(0) && source != address(this), "Invalid source address");
		_sourceAddr = source;
	}

}
