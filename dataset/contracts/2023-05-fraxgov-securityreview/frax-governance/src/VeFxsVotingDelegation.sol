// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ======================= VeFxsVotingDelegation ======================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Jon Walch: https://github.com/jonwalch

// Contributors
// Dennis: https://github.com/denett
// Drake Evans: https://github.com/DrakeEvans
// Jamie Turley: https://github.com/jyturley

// Reviewers
// Sam Kazemian: https://github.com/samkazemian

// ====================================================================

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC5805 } from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import { IVeFxs } from "./interfaces/IVeFxs.sol";
import { IVeFxsVotingDelegation } from "./interfaces/IVeFxsVotingDelegation.sol";

/// @title VeFxsVotingDelegation
/// @author Jon Walch (Frax Finance) https://github.com/jonwalch
/// @notice Contract that keeps track of voting weights and delegations, leveraging veFXS
contract VeFxsVotingDelegation is EIP712, IERC5805 {
    using SafeCast for uint256;

    /// @notice A week
    uint256 public constant WEEK = 7 days;

    /// @notice Max veFXS lock duration
    uint256 public constant MAX_LOCK_DURATION = 365 days * 4;

    /// @notice vote weight multiplier taken from veFXS
    uint256 public constant VOTE_WEIGHT_MULTIPLIER = 3;

    /// @notice Typehash needed for delegations by signature
    /// @dev keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)")
    bytes32 public constant DELEGATION_TYPEHASH = 0xe48329057bfd03d55e49b547132e39cffd9c1820ad7b9d4c5307691425d15adf;

    /// @notice veFXS contract
    IVeFxs public immutable VE_FXS;

    /// @notice Nonces needed for delegations by signature
    mapping(address signer => uint256 nonce) public $nonces;

    /// @notice Mapping from delegator to delegate including additional parameters for our weight calculations.
    mapping(address delegator => IVeFxsVotingDelegation.Delegation delegate) public $delegations;

    /// @notice Mapping from delegate to their checkpoints. Checkpoints correspond to daily rounded dates of delegation.
    mapping(address delegate => IVeFxsVotingDelegation.DelegateCheckpoint[]) public $delegateCheckpoints;

    /// @notice Mapping from delegate to weekly rounded time of expiry to the aggregated values at time of expiration. Mirrors veFXS expiration.
    mapping(address delegate => mapping(uint256 week => IVeFxsVotingDelegation.Expiration)) public $expiredDelegations;

    /// @notice The ```constructor``` function is called on deployment
    /// @param veFxs Address of veFXS contract
    constructor(address veFxs) EIP712("VeFxsVotingDelegation", "1") {
        VE_FXS = IVeFxs(veFxs);
    }

    /// @notice The ```getCheckpoint``` function is called to retrieve a specific delegation checkpoint
    /// @dev Get the checkpoint for a delegate at a given index.
    /// @param delegateAddress Address of delegate
    /// @param index Integer index of the checkpoint
    /// @return delegateCheckpoint DelegateCheckpoint of ```delegate``` at ```index```
    function getCheckpoint(
        address delegateAddress,
        uint32 index
    ) external view returns (IVeFxsVotingDelegation.DelegateCheckpoint memory) {
        return $delegateCheckpoints[delegateAddress][index];
    }

    /// @notice The ```_calculateDelegatedWeight``` function calculates weight delegated to ```account``` accounting for any weight that expired since the nearest checkpoint
    /// @dev May include own weight if account previously delegated to someone else and then back to themselves
    /// @param voter Address of voter
    /// @param timestamp A block.timestamp, typically corresponding to a proposal snapshot
    /// @return delegatedWeight Voting weight corresponding to all ```delegateAccount```'s received delegations
    function _calculateDelegatedWeight(
        address voter,
        uint256 timestamp
    ) internal view returns (uint256 delegatedWeight) {
        // Check if delegate account has any delegations
        IVeFxsVotingDelegation.DelegateCheckpoint memory checkpoint = _checkpointBinarySearch({
            _$checkpoints: $delegateCheckpoints[voter],
            timestamp: timestamp
        });

        // If checkpoint is empty, short circuit and return 0 delegated weight
        if (checkpoint.timestamp == 0) {
            return 0;
        }

        // It's possible that some delegated veFXS has expired.
        // Add up all expirations during this time period, week by week.
        (uint256 totalExpiredBias, uint256 totalExpiredSlope, uint256 totalExpiredFxs) = _calculateExpirations({
            account: voter,
            start: checkpoint.timestamp,
            end: timestamp,
            checkpoint: checkpoint
        });

        uint256 expirationAdjustedBias = checkpoint.normalizedBias - totalExpiredBias;
        uint256 expirationAdjustedSlope = checkpoint.normalizedSlope - totalExpiredSlope;
        uint256 expirationAdjustedFxs = checkpoint.totalFxs - totalExpiredFxs;

        uint256 voteDecay = expirationAdjustedSlope * timestamp;
        uint256 biasAtTimestamp = (expirationAdjustedBias > voteDecay) ? expirationAdjustedBias - voteDecay : 0;

        delegatedWeight = expirationAdjustedFxs + (VOTE_WEIGHT_MULTIPLIER * biasAtTimestamp);
    }

    /// @notice The ```_calculateVotingWeight``` function calculates ```account```'s voting weight. Is 0 if they ever delegated and the delegation is in effect.
    /// @param voter Address of voter
    /// @param timestamp A block.timestamp, typically corresponding to a proposal snapshot
    /// @return votingWeight Voting weight corresponding to ```account```'s veFXS balance
    function _calculateVotingWeight(address voter, uint256 timestamp) internal view returns (uint256) {
        // If lock is expired they have no voting weight
        if (VE_FXS.locked(voter).end <= timestamp) return 0;

        uint256 firstDelegationTimestamp = $delegations[voter].firstDelegationTimestamp;
        // Never delegated OR this timestamp is before the first delegation by account
        if (firstDelegationTimestamp == 0 || timestamp < firstDelegationTimestamp) {
            try VE_FXS.balanceOf({ addr: voter, _t: timestamp }) returns (uint256 _balance) {
                return _balance;
            } catch {}
        }
        return 0;
    }

    /// @notice The ```calculateExpirations``` function calculates all expired delegations for an account since the last checkpoint.
    /// @dev Can be used in tandem with writeNewCheckpointForExpirations() to write a new checkpoint
    /// @dev Long time periods between checkpoints can increase gas costs for delegate() and castVote()
    /// @dev See _calculateExpirations
    /// @param delegateAddress Address of delegate
    /// @return calculatedCheckpoint A new DelegateCheckpoint to write based on expirations since previous checkpoint
    function calculateExpiredDelegations(
        address delegateAddress
    ) public view returns (IVeFxsVotingDelegation.DelegateCheckpoint memory calculatedCheckpoint) {
        IVeFxsVotingDelegation.DelegateCheckpoint[] storage $userDelegationCheckpoints = $delegateCheckpoints[
            delegateAddress
        ];

        // This ensures that checkpoints take effect at the next epoch
        uint256 checkpointTimestamp = ((block.timestamp / 1 days) * 1 days) + 1 days;
        uint256 checkpointsLength = $userDelegationCheckpoints.length;

        // Nothing to expire if no one delegated to you
        if (checkpointsLength == 0) return calculatedCheckpoint;

        IVeFxsVotingDelegation.DelegateCheckpoint memory lastCheckpoint = $userDelegationCheckpoints[
            checkpointsLength - 1
        ];

        // Nothing expired because the most recent checkpoint is already written
        if (lastCheckpoint.timestamp == checkpointTimestamp) {
            return calculatedCheckpoint;
        }

        (uint256 totalExpiredBias, uint256 totalExpiredSlope, uint256 totalExpiredFxs) = _calculateExpirations({
            account: delegateAddress,
            start: lastCheckpoint.timestamp,
            end: checkpointTimestamp,
            checkpoint: lastCheckpoint
        });

        // All will be 0 if no expirations, only need to check one of them
        if (totalExpiredFxs == 0) return calculatedCheckpoint;

        /// NOTE: Checkpoint values will always be larger than or equal to expired values
        unchecked {
            calculatedCheckpoint = IVeFxsVotingDelegation.DelegateCheckpoint({
                timestamp: uint128(checkpointTimestamp),
                normalizedBias: uint128(lastCheckpoint.normalizedBias - totalExpiredBias),
                normalizedSlope: uint128(lastCheckpoint.normalizedSlope - totalExpiredSlope),
                totalFxs: uint128(lastCheckpoint.totalFxs - totalExpiredFxs)
            });
        }
    }

    /// @notice The ```writeNewCheckpointForExpirations``` function writes a new checkpoint if any weight has expired since the previous checkpoint
    /// @dev Long time periods between checkpoints can increase gas costs for delegate() and castVote()
    /// @dev See _calculateExpirations
    /// @param delegateAddress Address of delegate
    function writeNewCheckpointForExpiredDelegations(address delegateAddress) external {
        IVeFxsVotingDelegation.DelegateCheckpoint memory newCheckpoint = calculateExpiredDelegations(delegateAddress);

        if (newCheckpoint.timestamp == 0) revert IVeFxsVotingDelegation.NoExpirations();

        $delegateCheckpoints[delegateAddress].push(newCheckpoint);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice The ```_getVotingWeight``` function calculates a voter's voting weight at ```timestamp```
    /// @param voter Address of voter
    /// @param timestamp A block.timestamp, typically corresponding to a proposal snapshot
    /// @return totalVotingWeight Voting weight of ```voter``` at ```timestamp```
    function _getVotingWeight(address voter, uint256 timestamp) internal view returns (uint256 totalVotingWeight) {
        totalVotingWeight =
            _calculateVotingWeight({ voter: voter, timestamp: timestamp }) +
            _calculateDelegatedWeight({ voter: voter, timestamp: timestamp });
    }

    /// @notice The ```getVotes``` function calculates a voter's weight at ```timestamp```
    /// @param voter Address of voter
    /// @param timepoint A block.timestamp, typically corresponding to a proposal snapshot
    /// @return votingWeight Voting weight of ```voterAddress``` at ```timepoint```
    function getVotes(address voter, uint256 timepoint) external view returns (uint256) {
        return _getVotingWeight({ voter: voter, timestamp: timepoint });
    }

    /// @notice The ```getVotes``` function calculates a voter's weight at the current block.timestamp
    /// @param voter Address of voter
    /// @return votingWeight Voting weight of ```voterAddress``` at ```block.timestamp```
    function getVotes(address voter) external view returns (uint256 votingWeight) {
        votingWeight = _getVotingWeight({ voter: voter, timestamp: block.timestamp });
    }

    /// @notice The ```getPastVotes``` function calculates a voter's weight at ```timepoint```
    /// @param voter Address of voter
    /// @param timepoint A block.timestamp, typically corresponding to a proposal snapshot, must be in past
    /// @return pastVotingWeight Voting weight of ```account``` at ```timepoint``` in past
    function getPastVotes(address voter, uint256 timepoint) external view returns (uint256 pastVotingWeight) {
        if (timepoint >= block.timestamp) revert IVeFxsVotingDelegation.TimestampInFuture();

        pastVotingWeight = _getVotingWeight({ voter: voter, timestamp: timepoint });
    }

    /// @notice The ```getPastTotalSupply``` function retrieves the total supply of veFXS at ```blockNumber```
    /// @dev Must use block.number instead of timestamp because VE_FXS.totalSupply(timestamp) doesn't work for historical values.
    /// @param blockNumber block.number of total supply, must be in past
    /// @return pastTotalSupply veFXS supply at ```blockNumber```
    function getPastTotalSupply(uint256 blockNumber) external view returns (uint256 pastTotalSupply) {
        // Future blocks are not valid
        if (blockNumber >= block.number) revert IVeFxsVotingDelegation.BlockNumberInFuture();

        // Our total voting weight isn't the same as VE_FXS.totalSupplyAt(blockNumber) because
        // we expire all voting weight when the lock ends, which also may not be accounted for yet.
        // This is close enough.
        pastTotalSupply = VE_FXS.totalSupplyAt(blockNumber);
    }

    /// @notice The ```delegates``` function returns who the address of the delegate, that delegatorAddress has chosen
    /// @param delegator Address of delegator
    /// @return delegateAddress Address of the delegate
    function delegates(address delegator) external view returns (address delegateAddress) {
        delegateAddress = $delegations[delegator].delegate;
    }

    /// @notice The ```delegate``` function delegates votes from signer to ```delegatee``` at the next epoch
    /// @param delegatee Address to delegate to
    function delegate(address delegatee) external {
        _delegate({ delegator: msg.sender, delegatee: delegatee });
    }

    /// @notice The ```delegate``` function delegates votes from signer to ```delegatee```
    /// @param delegatee Address to delegate to
    /// @param nonce Nonce of signed message
    /// @param expiry Expiry time of message
    /// @param v Recovery ID
    /// @param r Output of an ECDSA signature
    /// @param s Output of an ECDSA signature
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        // Revert if signature is expired
        if (block.timestamp > expiry) revert IVeFxsVotingDelegation.SignatureExpired();

        address signer = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry))),
            v,
            r,
            s
        );

        // Increment nonce and check against incremented value
        if (nonce != $nonces[signer]++) revert IVeFxsVotingDelegation.InvalidSignatureNonce();
        _delegate(signer, delegatee);
    }

    /// @notice The ```_delegate``` function delegates votes from signer to ```delegatee``` at the next epoch
    /// @param delegator Caller delegating their weight
    /// @param delegatee Address to delegate to
    /// @dev An account can only delegate to one account at a time. The previous delegation will be overwritten.
    /// @dev To undelegate, ```delegatee``` should be ```address(delegator)```
    function _delegate(address delegator, address delegatee) internal {
        // Revert if delegating to self with address(0), should be address(delegator)
        if (delegatee == address(0)) revert IVeFxsVotingDelegation.IncorrectSelfDelegation();

        IVeFxsVotingDelegation.Delegation memory previousDelegation = $delegations[delegator];

        // This ensures that checkpoints take effect at the next epoch
        uint256 checkpointTimestamp = ((block.timestamp / 1 days) * 1 days) + 1 days;

        IVeFxsVotingDelegation.NormalizedVeFxsLockInfo
            memory normalizedDelegatorVeFxsLockInfo = _getNormalizedVeFxsLockInfo({
                delegator: delegator,
                checkpointTimestamp: checkpointTimestamp
            });

        _moveVotingPowerFromPreviousDelegate({
            previousDelegation: previousDelegation,
            checkpointTimestamp: checkpointTimestamp
        });

        _moveVotingPowerToNewDelegate({
            newDelegate: delegatee,
            delegatorVeFxsLockInfo: normalizedDelegatorVeFxsLockInfo,
            checkpointTimestamp: checkpointTimestamp
        });

        // NOTE: Unsafe casting because these values will never exceed the size of their respective types
        $delegations[delegator] = IVeFxsVotingDelegation.Delegation({
            delegate: delegatee,
            firstDelegationTimestamp: previousDelegation.firstDelegationTimestamp == 0
                ? uint48(checkpointTimestamp)
                : previousDelegation.firstDelegationTimestamp,
            expiry: uint48(normalizedDelegatorVeFxsLockInfo.expiry),
            bias: uint96(normalizedDelegatorVeFxsLockInfo.bias),
            fxs: uint96(normalizedDelegatorVeFxsLockInfo.fxs),
            slope: uint64(normalizedDelegatorVeFxsLockInfo.slope)
        });

        emit DelegateChanged({
            delegator: delegator,
            fromDelegate: previousDelegation.delegate,
            toDelegate: delegatee
        });
    }

    /// @notice The ```_getNormalizedVeFxsLockInfo``` function retrieves lock information from veFXS. We normalize and store this information to calculate voting weights
    /// @param delegator Address of the delegator
    /// @param checkpointTimestamp block.timestamp of the next checkpoint epoch
    /// @return normalizedVeFxsLockInfo Information about delegator's lock from veFXS contract, normalized
    function _getNormalizedVeFxsLockInfo(
        address delegator,
        uint256 checkpointTimestamp
    ) private view returns (IVeFxsVotingDelegation.NormalizedVeFxsLockInfo memory normalizedVeFxsLockInfo) {
        // Check expiry in case we need to revert
        uint256 expiry = VE_FXS.locked(delegator).end;
        if (expiry <= checkpointTimestamp) revert IVeFxsVotingDelegation.CantDelegateLockExpired();

        // Most recent epoch
        uint256 epoch = VE_FXS.user_point_epoch(delegator);
        // Values for delegator at the most recent epoch
        (int128 userBias, int128 userSlope, , , uint256 userFxs) = VE_FXS.user_point_history({
            _addr: delegator,
            _idx: epoch
        });
        // Get the timestamp of the last update in veFXS user history
        uint256 lastUpdate = VE_FXS.user_point_history__ts({ _addr: delegator, _idx: epoch });

        // Set return values
        normalizedVeFxsLockInfo.slope = SafeCast.toUint256(userSlope);
        normalizedVeFxsLockInfo.fxs = userFxs;
        normalizedVeFxsLockInfo.expiry = expiry;
        // Normalize bias to unix epoch, so all biases can be added and subtracted directly
        normalizedVeFxsLockInfo.bias = SafeCast.toUint256(userBias) + normalizedVeFxsLockInfo.slope * lastUpdate;
    }

    /// @notice The ```_checkpointBinarySearch``` function does a binary search for the closest checkpoint before ```timestamp```
    /// @param _$checkpoints Storage pointer to the account's DelegateCheckpoints
    /// @param timestamp block.timestamp to get voting power at, frequently proposal snapshot
    /// @return closestCheckpoint The closest DelegateCheckpoint before timestamp
    function _checkpointBinarySearch(
        IVeFxsVotingDelegation.DelegateCheckpoint[] storage _$checkpoints,
        uint256 timestamp
    ) private view returns (IVeFxsVotingDelegation.DelegateCheckpoint memory closestCheckpoint) {
        uint256 checkpointsLength = _$checkpoints.length;

        // What the newest checkpoint could be for timestamp (rounded to whole days). It will be earlier when checkpoints are sparse.
        uint256 roundedDownTimestamp = (timestamp / 1 days) * 1 days;
        // Newest checkpoint's timestamp (already rounded to whole days)
        uint256 lastCheckpointTimestamp = checkpointsLength > 0 ? _$checkpoints[checkpointsLength - 1].timestamp : 0;
        // The furthest back a checkpoint will ever be is the number of days delta between timestamp and the last
        // checkpoints timestamp. This happens when there was a checkpoint written every single day over that period.
        // If roundedDownTimestamp > lastCheckpointTimestamp that means that we can just use the last index as
        // the checkpoint.
        uint256 delta = lastCheckpointTimestamp > roundedDownTimestamp
            ? (lastCheckpointTimestamp - roundedDownTimestamp) / 1 days
            : 0;
        // low index is equal to the last checkpoints index minus the index delta
        uint256 low = (checkpointsLength > 0 && checkpointsLength - 1 > delta) ? checkpointsLength - 1 - delta : 0;

        uint256 high = checkpointsLength;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_$checkpoints[mid].timestamp > timestamp) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        closestCheckpoint = high == 0 ? closestCheckpoint : _$checkpoints[high - 1];
    }

    /// @notice The ```_moveVotingPowerFromPreviousDelegate``` function removes voting power from the previous delegate, handling expirations
    /// @notice and writing a new DelegateCheckpoint
    /// @param previousDelegation The delegator's previous delegation
    /// @param checkpointTimestamp block.timestamp of the next DelegateCheckpoint's epoch
    function _moveVotingPowerFromPreviousDelegate(
        IVeFxsVotingDelegation.Delegation memory previousDelegation,
        uint256 checkpointTimestamp
    ) private {
        // Remove voting power from previous delegate, if they exist
        if (previousDelegation.delegate != address(0)) {
            // Get the last Checkpoint for previous delegate
            IVeFxsVotingDelegation.DelegateCheckpoint[] storage $previousDelegationCheckpoints = $delegateCheckpoints[
                previousDelegation.delegate
            ];
            uint256 accountCheckpointsLength = $previousDelegationCheckpoints.length;
            // NOTE: we know that _accountsCheckpointLength > 0 because we have already checked that the previous delegation exists
            IVeFxsVotingDelegation.DelegateCheckpoint memory lastCheckpoint = $previousDelegationCheckpoints[
                accountCheckpointsLength - 1
            ];
            uint256 oldWeightOldDelegate = _getVotingWeight(previousDelegation.delegate, checkpointTimestamp);

            // Handle Expirations

            // Only subtract when the delegator's expiration is in the future. This way, the former delegates voting power
            // will still properly expire for proposals that happen between previousDelegation.expiry and a new delegation.
            // See testExpiredLockRedelegateNoVotingWeight().
            if (previousDelegation.expiry > checkpointTimestamp) {
                // Calculations
                IVeFxsVotingDelegation.Expiration memory expiration = $expiredDelegations[previousDelegation.delegate][
                    previousDelegation.expiry
                ];
                // All expiration fields will never exceed their size so subtraction doesnt need to be checked
                // and they can be unsafely cast
                unchecked {
                    expiration.bias -= uint96(previousDelegation.bias);
                    expiration.slope -= uint64(previousDelegation.slope);
                    expiration.fxs -= uint96(previousDelegation.fxs);
                }

                // Effects
                $expiredDelegations[previousDelegation.delegate][previousDelegation.expiry] = expiration;
            }

            {
                // Calculate new checkpoint
                IVeFxsVotingDelegation.DelegateCheckpoint memory newCheckpoint = _calculateCheckpoint({
                    previousCheckpoint: lastCheckpoint,
                    account: previousDelegation.delegate,
                    isDeltaPositive: false,
                    deltaBias: previousDelegation.bias,
                    deltaSlope: previousDelegation.slope,
                    deltaFxs: previousDelegation.fxs,
                    checkpointTimestamp: checkpointTimestamp,
                    previousDelegationExpiry: previousDelegation.expiry
                });

                // Write new checkpoint
                _writeCheckpoint({
                    $userDelegationCheckpoints: $previousDelegationCheckpoints,
                    accountCheckpointsLength: accountCheckpointsLength,
                    newCheckpoint: newCheckpoint,
                    lastCheckpoint: lastCheckpoint
                });
            }

            // NOTE: oldWeightOldDelegate has had voting power decay since the previous event, meaning that
            // this event shouldn't be relied up. We did our best to conform to the standard.
            emit DelegateVotesChanged({
                delegate: previousDelegation.delegate,
                previousBalance: oldWeightOldDelegate,
                newBalance: _getVotingWeight({ voter: previousDelegation.delegate, timestamp: checkpointTimestamp })
            });
        }
    }

    /// @notice The ```_moveVotingPowerToNewDelegate``` function adds voting power to the new delegate, handling expirations
    /// @notice and writing a new DelegateCheckpoint
    /// @param newDelegate The new delegate that is being delegated to
    /// @param delegatorVeFxsLockInfo Information about the delegator's veFXS lock
    /// @param checkpointTimestamp block.timestamp of the next DelegateCheckpoint's epoch
    function _moveVotingPowerToNewDelegate(
        address newDelegate,
        IVeFxsVotingDelegation.NormalizedVeFxsLockInfo memory delegatorVeFxsLockInfo,
        uint256 checkpointTimestamp
    ) private {
        // Get the last checkpoint for the new delegate
        IVeFxsVotingDelegation.DelegateCheckpoint[] storage $newDelegateCheckpoints = $delegateCheckpoints[newDelegate];
        uint256 accountCheckpointsLength = $newDelegateCheckpoints.length;
        IVeFxsVotingDelegation.DelegateCheckpoint memory lastCheckpoint = accountCheckpointsLength == 0
            ? IVeFxsVotingDelegation.DelegateCheckpoint(0, 0, 0, 0)
            : $newDelegateCheckpoints[accountCheckpointsLength - 1];
        uint256 oldWeightNewDelegate = _getVotingWeight(newDelegate, checkpointTimestamp);

        // Handle expiration
        // Calculations
        IVeFxsVotingDelegation.Expiration memory expiration = $expiredDelegations[newDelegate][
            delegatorVeFxsLockInfo.expiry
        ];

        // NOTE: All expiration fields will never exceed their size so addition doesnt need to be checked
        // and can be unsafely cast
        unchecked {
            expiration.bias += uint96(delegatorVeFxsLockInfo.bias);
            expiration.slope += uint64(delegatorVeFxsLockInfo.slope);
            expiration.fxs += uint96(delegatorVeFxsLockInfo.fxs);
        }
        // Effects
        $expiredDelegations[newDelegate][delegatorVeFxsLockInfo.expiry] = expiration;

        // Calculate new checkpoint
        IVeFxsVotingDelegation.DelegateCheckpoint memory newCheckpoint = _calculateCheckpoint({
            previousCheckpoint: lastCheckpoint,
            isDeltaPositive: true,
            account: newDelegate,
            deltaBias: delegatorVeFxsLockInfo.bias,
            deltaSlope: delegatorVeFxsLockInfo.slope,
            deltaFxs: delegatorVeFxsLockInfo.fxs,
            checkpointTimestamp: checkpointTimestamp,
            previousDelegationExpiry: 0 // not used
        });

        // Write new checkpoint
        _writeCheckpoint({
            $userDelegationCheckpoints: $newDelegateCheckpoints,
            accountCheckpointsLength: accountCheckpointsLength,
            newCheckpoint: newCheckpoint,
            lastCheckpoint: lastCheckpoint
        });

        // NOTE: oldWeightNewDelegate has had voting power decay since the previous event, meaning that
        // this event shouldn't be relied up. We did our best to conform to the standard.
        emit DelegateVotesChanged({
            delegate: newDelegate,
            previousBalance: oldWeightNewDelegate,
            newBalance: _getVotingWeight({ voter: newDelegate, timestamp: checkpointTimestamp })
        });
    }

    /// @notice The ```_calculateCheckpoint``` function calculates the values to be written for the new DelegateCheckpoint
    /// @param previousCheckpoint The previous checkpoint for account
    /// @param account The account to calculate the expirations for
    /// @param isDeltaPositive Whether adding or subtracting from the previous checkpoint
    /// @param deltaBias Amount of bias to add or subtract
    /// @param deltaSlope Amount of slope to add or subtract
    /// @param deltaFxs Amount of FXS to add or subtract
    /// @param checkpointTimestamp block.timestamp of the next DelegateCheckpoint's epoch
    /// @param previousDelegationExpiry When the previous delegation expires
    /// @return newCheckpoint The new DelegateCheckpoint to be stored
    function _calculateCheckpoint(
        IVeFxsVotingDelegation.DelegateCheckpoint memory previousCheckpoint,
        address account,
        bool isDeltaPositive,
        uint256 deltaBias,
        uint256 deltaSlope,
        uint256 deltaFxs,
        uint256 checkpointTimestamp,
        uint256 previousDelegationExpiry
    ) private view returns (IVeFxsVotingDelegation.DelegateCheckpoint memory newCheckpoint) {
        // If this is the first checkpoint, create a new one and early return
        if (previousCheckpoint.timestamp == 0) {
            return
                IVeFxsVotingDelegation.DelegateCheckpoint({
                    // can be unsafely cast because values will never exceed uint128 max
                    timestamp: uint128(checkpointTimestamp),
                    normalizedBias: uint128(deltaBias),
                    normalizedSlope: uint128(deltaSlope),
                    totalFxs: uint128(deltaFxs)
                });
        }

        newCheckpoint.timestamp = previousCheckpoint.timestamp;
        newCheckpoint.normalizedBias = previousCheckpoint.normalizedBias;
        newCheckpoint.normalizedSlope = previousCheckpoint.normalizedSlope;
        newCheckpoint.totalFxs = previousCheckpoint.totalFxs;

        // All checkpoint fields will never exceed their size so addition and subtraction doesnt need to be checked
        unchecked {
            // Add or subtract the delta to the previous checkpoint
            if (isDeltaPositive) {
                newCheckpoint.normalizedBias += uint128(deltaBias);
                newCheckpoint.normalizedSlope += uint128(deltaSlope);
                newCheckpoint.totalFxs += uint128(deltaFxs);
            } else {
                // only subtract the weight from this account if it has not already expired in a previous checkpoint
                if (previousDelegationExpiry > previousCheckpoint.timestamp) {
                    newCheckpoint.normalizedBias -= uint128(deltaBias);
                    newCheckpoint.normalizedSlope -= uint128(deltaSlope);
                    newCheckpoint.totalFxs -= uint128(deltaFxs);
                }
            }

            // If there have been expirations, incorporate the adjustments by subtracting them from the checkpoint
            if (newCheckpoint.timestamp != checkpointTimestamp) {
                (uint256 totalExpiredBias, uint256 totalExpiredSlope, uint256 totalExpiredFxs) = _calculateExpirations({
                    account: account,
                    start: newCheckpoint.timestamp,
                    end: checkpointTimestamp,
                    checkpoint: previousCheckpoint
                });

                newCheckpoint.timestamp = uint128(checkpointTimestamp);
                newCheckpoint.normalizedBias -= uint128(totalExpiredBias);
                newCheckpoint.normalizedSlope -= uint128(totalExpiredSlope);
                newCheckpoint.totalFxs -= uint128(totalExpiredFxs);
            }
        }
    }

    /// @notice The ```_writeCheckpoint``` function pushes a new checkpoint to the array or updates the most recent one if it already exists for the current epoch
    /// @param $userDelegationCheckpoints Pointer to the user's delegation checkpoints
    /// @param accountCheckpointsLength The length of the user's delegation checkpoints
    /// @param newCheckpoint The new checkpoint returned from _calculateCheckpoint()
    /// @param lastCheckpoint The most recent delegate checkpoint
    function _writeCheckpoint(
        IVeFxsVotingDelegation.DelegateCheckpoint[] storage $userDelegationCheckpoints,
        uint256 accountCheckpointsLength,
        IVeFxsVotingDelegation.DelegateCheckpoint memory newCheckpoint,
        IVeFxsVotingDelegation.DelegateCheckpoint memory lastCheckpoint
    ) internal {
        // If the newCheckpoint has the same timestamp as the last checkpoint, overwrite it
        if (accountCheckpointsLength > 0 && lastCheckpoint.timestamp == newCheckpoint.timestamp) {
            $userDelegationCheckpoints[accountCheckpointsLength - 1] = newCheckpoint;
        } else {
            // Otherwise, push a new checkpoint
            $userDelegationCheckpoints.push(newCheckpoint);
        }
    }

    /// @notice The ```_calculateExpirations``` function generates a summation of all bias, slope, and fxs for all delegations that expire during the specified time window for ```account```
    /// @param account Delegate account to generate summations for
    /// @param start Timestamp to start the summations from. The start is not included
    /// @param end Timestamp to end the summations. The end is included
    /// @param checkpoint Checkpoint to start expirations at
    /// @return totalExpiredBias Total bias that expired for delegate ```account``` during timeframe
    /// @return totalExpiredSlope Total slope that expired for delegate ```account``` during timeframe
    /// @return totalExpiredFxs Total FXS that expired for delegate ```account``` during timeframe
    function _calculateExpirations(
        address account,
        uint256 start,
        uint256 end,
        IVeFxsVotingDelegation.DelegateCheckpoint memory checkpoint
    ) private view returns (uint256 totalExpiredBias, uint256 totalExpiredSlope, uint256 totalExpiredFxs) {
        unchecked {
            // Maximum lock time for veFXS is 4 years, it will all be expired
            if (end > start + MAX_LOCK_DURATION) {
                totalExpiredBias = checkpoint.normalizedBias;
                totalExpiredSlope = checkpoint.normalizedSlope;
                totalExpiredFxs = checkpoint.totalFxs;
            } else {
                // Total values will always be less than or equal to a checkpoint's values
                uint256 currentWeek = WEEK + (start / WEEK) * WEEK;
                mapping(uint256 => IVeFxsVotingDelegation.Expiration)
                    storage $delegateExpirations = $expiredDelegations[account];
                // Sum values from currentWeek until end
                while (currentWeek <= end) {
                    IVeFxsVotingDelegation.Expiration memory expiration = $delegateExpirations[currentWeek];
                    totalExpiredBias += expiration.bias;
                    totalExpiredSlope += expiration.slope;
                    totalExpiredFxs += expiration.fxs;
                    currentWeek += WEEK;
                }
            }
        }
    }
}
