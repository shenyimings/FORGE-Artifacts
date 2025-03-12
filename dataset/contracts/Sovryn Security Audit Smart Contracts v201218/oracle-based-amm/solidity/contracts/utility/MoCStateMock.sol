pragma solidity 0.4.26;

import "./interfaces/IMoCState.sol";

contract MoCStateMock is IMoCState {
	uint256 public value;

	function bproUsdPrice() public view returns (uint256) {
		return value;
	}

	function setValue(uint256 _value) public {
		value = _value;
	}
}
