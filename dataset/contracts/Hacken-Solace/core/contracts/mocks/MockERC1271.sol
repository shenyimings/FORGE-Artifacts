// SPDX-License-Identifier: GPL-3.0-or-later
// code borrowed from @uniswap/v3-periphery
pragma solidity 0.8.6;

import "./../interfaces/utils/IERC1271.sol";


/// @title Interface for verifying contract-based account signatures
/// @notice Interface that verifies provided signature for the data
/// @dev Interface defined by EIP-1271
contract MockERC1271 is IERC1271 {

    // hash => signature => valid or not
    mapping(bytes32 => mapping(bytes => bool)) private _validSignatures;

    /// @notice Returns whether the provided signature is valid for the provided data
    /// @dev MUST return the bytes4 magic value 0x1626ba7e when function passes.
    /// MUST NOT modify state (using STATICCALL for solc < 0.5, view modifier for solc > 0.5).
    /// MUST allow external calls.
    /// @param hash Hash of the data to be signed
    /// @param signature Signature byte array associated with _data
    /// @return magicValue The bytes4 magic value 0x1626ba7e
    function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4 magicValue) {
        return ((_validSignatures[hash][signature])
          ? bytes4(0x1626ba7e)
          : bytes4(0xffffffff));
    }

    // adds or removes a signature
    function setSignature(bytes32 hash, bytes memory signature, bool valid) external {
        _validSignatures[hash][signature] = valid;
    }
}
