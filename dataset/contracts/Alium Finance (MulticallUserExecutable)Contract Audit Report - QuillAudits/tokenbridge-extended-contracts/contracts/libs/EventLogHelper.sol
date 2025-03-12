// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library EventLogHelper {
    /// @dev Calculates asset identifier.
    /// @param _tokenAddress Address of the asset on the other chain.
    /// @param _chainId Current chain id.
    function getAssetId(uint256 _chainId, address _tokenAddress)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_chainId, _tokenAddress));
    }
}
