// SPDX-License-Identifier: ISC
pragma solidity >=0.8.19;

interface IVeFxsVotingDelegation {
    /// Represents the values of a single delegation at the time `delegate()` is called,
    /// to be subtracted when removing delegation
    struct Delegation {
        address delegate;
        uint48 firstDelegationTimestamp;
        uint48 expiry;
        // __________
        uint96 bias;
        uint96 fxs;
        uint64 slope;
    }

    /// A representation of a delegate and all its delegators at a particular timestamp
    struct DelegateCheckpoint {
        uint128 normalizedBias;
        uint128 totalFxs;
        // _________
        uint128 normalizedSlope;
        uint128 timestamp; // Rounded up to the nearest day
    }

    /// Represents the total bias, slope, and FXS amount of all accounts that expire for a specific delegate
    /// in a particular week
    struct Expiration {
        uint96 bias;
        uint96 fxs;
        uint64 slope;
    }

    // Only used in memory
    struct NormalizedVeFxsLockInfo {
        uint256 bias;
        uint256 slope;
        uint256 fxs;
        uint256 expiry;
    }

    function $delegateCheckpoints(
        address,
        uint256
    ) external view returns (uint128 normalizedBias, uint128 totalFxs, uint128 normalizedSlope, uint128 timestamp);

    function $delegations(
        address
    )
        external
        view
        returns (
            address delegate,
            uint48 firstDelegationTimestamp,
            uint48 expiry,
            uint96 bias,
            uint96 fxs,
            uint64 slope
        );

    function $expiredDelegations(address, uint256) external view returns (uint96 bias, uint96 fxs, uint64 slope);

    function $nonces(address) external view returns (uint256);

    function CLOCK_MODE() external pure returns (string memory);

    function DELEGATION_TYPEHASH() external view returns (bytes32);

    function MAX_LOCK_DURATION() external view returns (uint256);

    function VE_FXS() external view returns (address);

    function VOTE_WEIGHT_MULTIPLIER() external view returns (uint256);

    function WEEK() external view returns (uint256);

    function calculateExpiredDelegations(
        address delegateAddress
    ) external view returns (DelegateCheckpoint memory calculatedCheckpoint);

    function clock() external view returns (uint48);

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    function delegates(address delegator) external view returns (address delegateAddress);

    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );

    function getCheckpoint(address delegateAddress, uint32 index) external view returns (DelegateCheckpoint memory);

    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256 pastTotalSupply);

    function getPastVotes(address voter, uint256 timepoint) external view returns (uint256 pastVotingWeight);

    function getVotes(address voter) external view returns (uint256 votingWeight);

    function getVotes(address voter, uint256 timepoint) external view returns (uint256);

    function writeNewCheckpointForExpiredDelegations(address delegateAddress) external;

    error BlockNumberInFuture();
    error CantDelegateLockExpired();
    error IncorrectSelfDelegation();
    error InvalidSignatureNonce();
    error NoExpirations();
    error SignatureExpired();
    error TimestampInFuture();
}
