// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRedeemChecker {
    /// @notice Return whether a specific address is qualified to redeem NFT.
    /// @param recipient The recipient of NFT.
    function qualified(address recipient) external view returns (bool);
}
