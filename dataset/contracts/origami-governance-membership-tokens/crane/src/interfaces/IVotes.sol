// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (governance/utils/IVotes.sol)
pragma solidity 0.8.16;

/**
 * @notice Common interface for {ERC20Votes}, {ERC721Votes}, and other {Votes}-enabled contracts.
 */
interface IVotes {
    /// @dev Emitted when an account changes their delegatee.
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @dev Emitted when a token transfer or delegatee change results in changes to a delegatee's number of votes.
    event DelegateVotesChanged(address indexed delegatee, uint256 previousBalance, uint256 newBalance);

    /// @dev Returns the current amount of votes that `account` has.
    function getVotes(address account) external view returns (uint256);

    /// @notice Returns the amount of votes that `account` had at the end of a past block's timestamp.
    function getPastVotes(address account, uint256 timestamp) external view returns (uint256);

    /**
     * @notice Returns the total supply of votes available at the end of a past block's timestamp.
     * @param timestamp The timestamp to check the total supply of votes at.
     * @return The total supply of votes available at the last checkpoint before `timestamp`.
     *
     * NOTE: This value is the sum of all available votes, which is not necessarily the sum of all delegated votes.
     * Votes that have not been delegated are still part of total supply, even though they would not participate in a
     * vote.
     */
    function getPastTotalSupply(uint256 timestamp) external view returns (uint256);

    /// @notice Returns the EIP712 domain separator for this contract.
    function domainSeparatorV4() external view returns (bytes32);

    /**
     * @notice Returns the current nonce for `delegator`.
     * @dev Used to prevent replay attacks when delegating by signature.
     * @param delegator The address of the delegator to get the nonce for.
     * @return The nonce for `delegator`.
     */
    function getDelegatorNonce(address delegator) external view returns (uint256);

    /**
     * @notice Returns the delegatee that `account` has chosen.
     * @param account The address of the account to get the delegatee for.
     * @return The address of the delegatee for `account`.
     */
    function delegates(address account) external view returns (address);

    /**
     * @notice Delegates votes from the sender to `delegatee`.
     * @param delegatee The address to delegate votes to.
     */
    function delegate(address delegatee) external;

    /**
     * @notice Delegates votes from the signer to `delegatee`.
     * @dev This allows execution by proxy of a delegation, so that signers do not need to pay gas.
     * @param delegatee The address to delegate votes to.
     * @param nonce The nonce of the delegator.
     * @param expiry The timestamp at which the delegation expires.
     * @param v The recovery byte of the signature.
     * @param r Half of the ECDSA signature pair.
     * @param s Half of the ECDSA signature pair.
     */
    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
}
