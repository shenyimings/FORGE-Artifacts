// SPDX-License-Identifier: MIT
/*
This is a Stacker.vc FarmToken version 1 contract. It deploys a rebase token where it rebases to be equivalent to it's underlying token. 1 stackUSDT = 1 USDT.
The underlying assets are used to farm on different smart contract and produce yield via the ever-expanding DeFi ecosystem.

NOTE: 
This is an abstract contract, and two functions need to be implemented for a valid deployment: 
_verify(address _account, uint256 _amountUnderlyingToSend) --> in order to pass any locks on sending funds/withdrawing
_getTotalUnderlying() --> to know the total amount of funds under management

THANKS! 
To Lido DAO for the inspiration in more ways than one, but especially for a lot of the code here. 
If you haven't already, stake your ETH for ETH2.0 with Lido.fi!
Also thanks for Aragon for hosting our Stacker Ventures DAO, and for more inspiration!
*/

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol"; // call ERC20 safely
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract FarmTokenV1 is IERC20 {
	using SafeMath for uint256;
	using Address for address;

	// shares are how a users balance is generated. For rebase tokens, balances are always generated at runtime, while shares stay constant.
	// shares is your proportion of the total pool of invested UnderlyingToken
	// shares are like a Compound.finance cToken, while our token balances are like an Aave aToken.
	mapping(address => uint256) private shares;
	mapping(address => mapping (address => uint256)) private allowances;

	uint256 public totalShares;

	string public name;
	string public symbol;
	string public underlying;
	address public underlyingContract;

	uint8 public decimals;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, uint8 _decimals, address _underlyingContract) public {
    	name = string(abi.encodePacked(abi.encodePacked("Stacker Ventures ", _name), " v1"));
    	symbol = string(abi.encodePacked("stack", _name));
    	underlying = _name;

    	decimals = _decimals;

    	underlyingContract = _underlyingContract;
    }

    // 1 stackToken = 1 underlying token
    function totalSupply() external override view returns (uint256){
    	return _getTotalUnderlying();
    }

    function totalUnderlying() external view returns (uint256){
    	return _getTotalUnderlying();
    }

    function balanceOf(address _account) public override view returns (uint256){
    	return getUnderlyingForShares(_sharesOf(_account));
    }

    // transfer tokens, not shares
    function transfer(address _recipient, uint256 _amount) external override returns (bool){
    	_verify(msg.sender, _amount);
    	_transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool){
    	_verify(_sender, _amount);
    	uint256 _currentAllowance = allowances[_sender][msg.sender];
        require(_currentAllowance >= _amount, "FARMTOKENV1: not enough allowance");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, _currentAllowance.sub(_amount));
        return true;
    }

    // this checks if a transfer/transferFrom/withdraw is allowed. There are some conditions on withdraws/transfers from new deposits
    // function stub, this needs to be implemented in a contract which inherits this for a valid deployment
    // IMPLEMENT THIS
    function _verify(address _account, uint256 _amountUnderlyingToSend) internal virtual;

    // allow tokens, not shares
    function allowance(address _owner, address _spender) external override view returns (uint256){
    	return allowances[_owner][_spender];
    }

    // approve tokens, not shares
    function approve(address _spender, uint256 _amount) external override returns (bool){
    	_approve(msg.sender, _spender, _amount);
        return true;
    }

    // shares of _account
    function sharesOf(address _account) external view returns (uint256) {
    	return _sharesOf(_account);
    }

    // how many shares for _amount of underlying?
    // if there are no shares, or no underlying yet, we are initing the contract or suffered a total loss
    // either way, init this state at 1:1 shares:underlying
    function getSharesForUnderlying(uint256 _amountUnderlying) public view returns (uint256){
    	uint256 _totalUnderlying = _getTotalUnderlying();
    	if (_totalUnderlying == 0){
    		return _amountUnderlying; // this will init at 1:1 _underlying:_shares
    	}
    	uint256 _totalShares = totalShares;
    	if (_totalShares == 0){
    		return _amountUnderlying; // this will init the first shares, expected contract underlying balance == 0, or there will be a bonus (doesn't belong to anyone so ok)
    	}

    	return _amountUnderlying.mul(_totalShares).div(_totalUnderlying);
    }

    // how many underlying for _amount of shares?
    // if there are no shares, or no underlying yet, we are initing the contract or suffered a total loss
    // either way, init this state at 1:1 shares:underlying
    function getUnderlyingForShares(uint256 _amountShares) public view returns (uint256){
    	uint256 _totalShares = totalShares;
    	if (_totalShares == 0){
    		return _amountShares; // this will init at 1:1 _shares:_underlying
    	}
    	uint256 _totalUnderlying = _getTotalUnderlying();
    	if (_totalUnderlying == 0){
    		return _amountShares; // this will init at 1:1 
    	}

    	return _amountShares.mul(_totalUnderlying).div(_totalShares);

    }

    function _sharesOf(address _account) internal view returns (uint256){
    	return shares[_account];
    }

    // function stub, this needs to be implemented in a contract which inherits this for a valid deployment
    // sum the contract balance + working balance withdrawn from the contract and actively farming
    // IMPLEMENT THIS
    function _getTotalUnderlying() internal virtual view returns (uint256);

    // in underlying
    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
    	uint256 _sharesToTransfer = getSharesForUnderlying(_amount);
    	_transferShares(_sender, _recipient, _sharesToTransfer);
    	emit Transfer(_sender, _recipient, _amount);
    }

    // in underlying
    function _approve(address _owner, address _spender, uint256 _amount) internal {
    	require(_owner != address(0), "FARMTOKENV1: from == 0x0");
        require(_spender != address(0), "FARMTOKENV1: to == 0x00");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transferShares(address _sender, address _recipient,  uint256 _amountShares) internal {
    	require(_sender != address(0), "FARMTOKENV1: from == 0x00");
        require(_recipient != address(0), "FARMTOKENV1: to == 0x00");

        uint256 _currentSenderShares = shares[_sender];
        require(_amountShares <= _currentSenderShares, "FARMTOKENV1: transfer amount exceeds balance");

        shares[_sender] = _currentSenderShares.sub(_amountShares);
        shares[_recipient] = shares[_recipient].add(_amountShares);
    }

    function _mintShares(address _recipient, uint256 _amountShares) internal {
    	require(_recipient != address(0), "FARMTOKENV1: to == 0x00");

        totalShares = totalShares.add(_amountShares);
        shares[_recipient] = shares[_recipient].add(_amountShares);

        // NOTE: we're not emitting a Transfer event from the zero address here
        // If we mint shares with no underlying, we basically just diluted everyone

        // It's not possible to send events from _everyone_ to reflect each balance dilution (ie: balance going down)

        // Not compliant to ERC20 standard...
    }

    function _burnShares(address _account, uint256 _amountShares) internal {
    	require(_account != address(0), "FARMTOKENV1: burn from == 0x00");

        uint256 _accountShares = shares[_account];
        require(_amountShares <= _accountShares, "FARMTOKENV1: burn amount exceeds balance");
        totalShares = totalShares.sub(_amountShares);

        shares[_account] = _accountShares.sub(_amountShares);

        // NOTE: we're not emitting a Transfer event to the zero address here 
        // If we burn shares without burning/withdrawing the underlying
        // then it looks like a system wide credit to everyones balance

        // It's not possible to send events to _everyone_ to reflect each balance credit (ie: balance going up)

        // Not compliant to ERC20 standard...
    }
}