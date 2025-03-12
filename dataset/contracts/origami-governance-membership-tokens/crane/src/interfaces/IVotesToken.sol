// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title Votes Token Interface
 * @author Origami
 * @notice Interface for tokens that can be used for voting. Part EIP-712 and part ERC20.
 * @custom:security-contact contract-security@joinorigami.com
 */
interface IVotesToken {
    /**
     * @notice returns the token balance for an account
     * @param owner the account to check
     * @return balance the token balance for the account
     */
    function balanceOf(address owner) external view returns (uint256 balance);
    /// @notice returns the token name for compatibility with EIP-712
    function name() external view returns (string memory);
    /// @notice returns the token symbol for compatibility with EIP-712
    function version() external pure returns (string memory);
}
