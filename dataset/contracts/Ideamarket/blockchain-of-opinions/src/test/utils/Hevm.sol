// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

// used at address 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
interface Hevm {
	/// @dev  Sets the block timestamp to x
	function warp(uint256 x) external;

	/// @dev Sets the block number to x
	function roll(uint256 x) external;

	/// @dev Sets the slot loc of contract c to val
	function load(address c, bytes32 loc) external returns (bytes32 val);

	/// @dev Signs the digest using the private key sk. Note that signatures produced via hevm.sign will leak the private key.
	function sign(uint256 sk, bytes32 digest)
		external
		returns (
			uint8 v,
			bytes32 r,
			bytes32 s
		);

	/// @dev Derives an ethereum address from the private key sk. Note that hevm.addr(0) will fail with BadCheatCode as 0 is an invalid ECDSA private key.
	function addr(uint256 sk) external returns (address addr);

	/// @dev Executes the arguments as a command in the system shell and returns stdout. Expects abi encoded values to be returned from the shell or an error will be thrown. Note that this cheatcode means test authors can execute arbitrary code on user machines as part of a call to dapp test, for this reason all calls to ffi will fail unless the --ffi flag is passed.
	function ffi(string[] calldata) external returns (bytes memory);
}
