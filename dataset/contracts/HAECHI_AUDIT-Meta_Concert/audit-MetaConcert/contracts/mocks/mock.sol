// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "hardhat/console.sol";
import "../erc20/ERC20Lockable.sol";
import "../erc20/ERC20Burnable.sol";
import "../erc20/ERC20Mintable.sol";
import "../library/Pausable.sol";
import "../library/Freezable.sol";
import "../METACONCERT.sol";

contract mockERC20 is METACONCERT, ERC20Mintable{

	function _transferTest(address from, address to, uint256 amount) public {
		_transfer(from,to,amount);
	}


	function _approveTest(address owner, address spender, uint256 amount) public {
		_approve(owner,spender,amount);
	}

	function _mintTest(address recipient, uint256 amount) public {
		_mint(recipient, amount);
	}

	function _burnTest(address burned, uint256 amount) public{
		_burn(burned,amount);
	}

	function _lockTest(address from, uint256 amount, uint256 due) public {
		_lock(from,amount,due);
	}

	function getTimeStamp() public view returns (uint256){
		return block.timestamp;
	}

	function setTimeStamp(uint256 time) public view returns(uint256){
		return block.timestamp+time;
	}

	function get_totalLocked(address addr) public view returns (uint256){
		return _totalLocked[addr];
	}

	function _unlockTest(address addr, uint256 idx) public {
		_unlock(addr,idx);
	}

	function checkLockTest(address from, uint256 amount) public view checkLock(from,amount) returns(uint256){
		return 1;
	}

	function set_mintingFinished(bool v) public {
		_mintingFinished = v;
	}

	function whenNotFrozenTest(address addr) public  whenNotFrozen(addr){

	}

	function _transferOwnershipTest(address addr) public{
		_transferOwnership(addr);
	}
}

