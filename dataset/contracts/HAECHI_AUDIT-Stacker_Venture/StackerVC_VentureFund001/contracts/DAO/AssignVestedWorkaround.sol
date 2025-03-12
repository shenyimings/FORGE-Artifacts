// SPDX-License-Identifier: MIT

/*
* A work around for assigning vested tokens, and also doing batch vestings in a single transaction. 
* You must give this smart contract permission to act as "assignTokens" in your Aragon DAO.
*/

pragma solidity ^0.6.11;

import "@openzeppelin/contracts/utils/Address.sol";

import "../Interfaces/ITokenManager.sol";

contract AssignVestedWorkaround {
	using Address for address;

	address public tokenManager;
	address public governance;

	uint256 public constant LOOP_LIMIT = 50;

	constructor(address _tokenManager) public {
		governance = msg.sender;
		tokenManager = _tokenManager;
	}

	function setGovernance(address _new) external {
		require(msg.sender == governance, "VESTED: !governance");
		governance = _new;
	}

	function setTokenManager(address _new) external {
		require(msg.sender == governance, "VESTED: !governance");
		tokenManager = _new;
	}

	function vest(address _receiver, uint256 _amount, uint64 _start, uint64 _cliff, uint64 _vested, bool _revokable) external {
		require(msg.sender == governance, "VESTED: !governance");

		_vest(_receiver, _amount, _start, _cliff, _vested, _revokable);
	}

	function vestMany(address[] calldata _receivers, uint256[] calldata _amounts, uint64[] calldata _starts, uint64[] calldata _cliffs, uint64[] calldata _vesteds, bool[] calldata _revokables) external {
		require(msg.sender == governance, "VESTED: !governance");
		require(_receivers.length == _amounts.length && _amounts.length == _starts.length && _amounts.length == _cliffs.length && _amounts.length == _vesteds.length && _amounts.length == _revokables.length, "VESTED: !length");
		require(_amounts.length <= LOOP_LIMIT, "VESTED: length>LOOP_LIMIT");

		for(uint256 i = 0; i < _amounts.length; i++){
			_vest(_receivers[i], _amounts[i], _starts[i], _cliffs[i], _vesteds[i], _revokables[i]);
		}
	}

	function _vest(address _receiver, uint256 _amount, uint64 _start, uint64 _cliff, uint64 _vested, bool _revokable) internal {
		// call the Aragon Token Manager to assignVested tokens
		ITokenManager(tokenManager).assignVested(
			_receiver,
			_amount,
			_start,
			_cliff,
			_vested,
			_revokable
		);
	}

}