// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

import {ITransferRestrictor} from "./ITransferRestrictor.sol";

/// @notice Core token contract interface for bridged assets.
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/IdShare.sol)
/// Minter, burner, and blacklist
interface IdShare {
    /// @notice Contract to restrict transfers
    function transferRestrictor() external view returns (ITransferRestrictor);

    /// @notice Mint tokens
    /// @param to Address to mint tokens to
    /// @param value Amount of tokens to mint
    /// @dev Only callable by approved minter and deployer
    /// @dev Not callable after split
    function mint(address to, uint256 value) external;

    /// @notice Burn tokens
    /// @param value Amount of tokens to burn
    /// @dev Only callable by approved burner
    /// @dev Deployer can always burn after split
    function burn(uint256 value) external;

    /**
     * @param account The address of the account
     * @return Whether the account is blacklisted
     * @dev Returns true if the account is blacklisted , if the account is the zero address
     */
    function isBlacklisted(address account) external view returns (bool);
}
