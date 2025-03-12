// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//
//interface IAMBMock {
//	function relayTokens(address _receiver, uint256 _value) external;
//	function relayTokens(address _receiver, address _test, uint256 _value) external;
//}

contract AMBMock /*is IAMBMock*/ {
	event ActionOnTransfer(address receiver);

	IERC20 public token;

	constructor(IERC20 _token) {
		token = _token;
	}

//	function relayTokens(address _receiver, uint256 _value) external virtual override {
//		address to = address(this);
//		token.transferFrom(msg.sender, to, _value);
//		emit ActionOnTransfer(_receiver);
//	}

	function relayTokens(address _receiver, address _test, uint256 _value) external {
		_test;
		address to = address(this);
		token.transferFrom(msg.sender, to, _value);
		emit ActionOnTransfer(_receiver);
	}
}
