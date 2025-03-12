// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title CheckpointVoteStorage
 * @dev This contract is used to store the checkpoints for votes and delegates
 * NB: This library is strictly internal so it does not deploy a new contract
 * h/t YAM Protocol for the binary search approach:
 * https://github.com/yam-finance/yam-protocol/blob/3960424bdd5e921b0e283fa7feae3f996c480e49/contracts/token/YAMGovernance.sol
 */
library Checkpoints {
    bytes32 public constant CHECKPOINT_STORAGE_POSITION = keccak256("com.origami.ivotes.checkpoints");
    bytes32 public constant DELEGATE_STORAGE_POSITION = keccak256("com.origami.ivotes.delegates");

    /**
     * @dev Emitted when an account changes their delegatee.
     */
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /**
     * @dev Emitted when a token transfer or delegatee change results in changes to a delegatee's number of votes.
     */
    event DelegateVotesChanged(address indexed delegatee, uint256 previousBalance, uint256 newBalance);

    /// @dev struct to store checkpoint data
    struct Checkpoint {
        uint256 timestamp;
        uint256 votes;
    }

    /// @dev struct to store information about checkpoint data
    struct CheckpointStorage {
        /**
         * @dev The number of checkpoints for the total supply of tokens
         */
        uint32 supplyCheckpointsCount;
        /**
         * @notice An indexed mapping of checkpoints for the total supply of tokens
         * @dev this allows for 4.3 billion supply checkpoints
         */
        mapping(uint32 => Checkpoint) supplyCheckpoints;
        /**
         * @dev The number of checkpoints for each `account`
         */
        mapping(address => uint32) voterCheckpointsCount;
        /**
         * @notice An indexed mapping of checkpoints for each account
         * @dev this allows for 4.3 billion checkpoints per account
         */
        mapping(address => mapping(uint32 => Checkpoint)) voterCheckpoints;
    }

    /// @dev struct to store delegate data
    struct DelegateStorage {
        mapping(address => address) delegates;
        mapping(address => uint256) nonces;
    }

    /// @dev Diamond storage pointer for checkpoint data
    function checkpointStorage() internal pure returns (CheckpointStorage storage cs) {
        bytes32 position = CHECKPOINT_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            cs.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    /**
     * @dev This is generalized to allow lookups in any indexed mapping of checkpoints
     * @param checkpoints the mapping with a sequence of checkpoints
     * @param count the sequence number of the desired checkpoint
     * @return weight the weight for the checkpoint specified by the count
     */
    function getWeight(mapping(uint32 => Checkpoint) storage checkpoints, uint32 count)
        internal
        view
        returns (uint256 weight)
    {
        if (count > 0) {
            uint32 index = count - 1;
            weight = checkpoints[index].votes;
        } else {
            weight = 0;
        }
    }

    /**
     * @dev This is generalized to allow lookups in any indexed mapping of checkpoints
     * @param checkpoints the mapping with a sequence of checkpoints
     * @param count the total number of checkpoints for param checkpoints
     * @param timestamp the timestamp of the snapshot
     * @return the weight for the latest checkpoint before the timestamp specified
     *
     * This uses a binary search to find the correct checkpoint, which has a
     * worst case of O(log n) where n is the number of checkpoints. In order to
     * further optimize this, without greatly increasing complexity, we check for
     * three common cases before resorting to binary search:
     *  * If there are no checkpoints, return 0
     *  * If the latest checkpoint is older than the specified timestamp, return the latest checkpoint
     *  * If the first checkpoint is newer than the specified timestamp, return 0
     * Otherwise, use binary search.
     */
    function getPastWeight(mapping(uint32 => Checkpoint) storage checkpoints, uint32 count, uint256 timestamp)
        internal
        view
        returns (uint256)
    {
        // If there are no checkpoints, return 0
        if (count == 0) {
            return 0;
        }

        // Most recent checkpoint is older than specified timestamp, use it
        if (checkpoints[count - 1].timestamp <= timestamp) {
            return checkpoints[count - 1].votes;
        }

        // First checkpoint is after the specified timestamp
        if (checkpoints[0].timestamp > timestamp) {
            return 0;
        }

        // Failing the above, binary search the checkpoints
        uint32 lower = 0;
        uint32 upper = count - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // rounds up
            Checkpoint memory cp = checkpoints[center];
            if (cp.timestamp == timestamp) {
                return cp.votes;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[lower].votes;
    }

    /**
     * @notice Get the voting weight from the most recent checkpoint for `account`
     * @param account The address of the account to get the votes of
     * @return votes The number of votes held by `account`, possibly zero
     */
    function getVotes(address account) internal view returns (uint256 votes) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.voterCheckpointsCount[account];
        return getWeight(cs.voterCheckpoints[account], count);
    }

    /**
     * @notice Get the voting weight for `account` as of `timestamp`
     * @param account The address of the account to get the votes of
     * @param timestamp The timestamp of the snapshot to retrieve the vote balance at
     * @return votes The number of votes held by `account` at `timestamp`, possibly zero
     */
    function getPastVotes(address account, uint256 timestamp) internal view returns (uint256 votes) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.voterCheckpointsCount[account];
        return getPastWeight(cs.voterCheckpoints[account], count, timestamp);
    }

    /**
     * @notice Get the total supply as of the most recent checkpoint
     * @return supply The total supply as of the most recent checkpoint
     */
    function getTotalSupply() internal view returns (uint256 supply) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.supplyCheckpointsCount;
        return getWeight(cs.supplyCheckpoints, count);
    }

    /**
     * @notice get the total supply as of the last checkpoint before `timestamp`
     * @dev this can be used for deriving Quorum
     * @param timestamp The timestamp of the snapshot to retrieve the total supply at
     * @return supply The total supply as of the most recent checkpoint before `timestamp`
     */
    function getPastTotalSupply(uint256 timestamp) internal view returns (uint256 supply) {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 count = cs.supplyCheckpointsCount;
        return getPastWeight(cs.supplyCheckpoints, count, timestamp);
    }

    // @dev Diamond storage pointer for delegation data
    function delegateStorage() internal pure returns (DelegateStorage storage ds) {
        bytes32 position = DELEGATE_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            ds.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    /**
     * @notice Returns the address of the account which `account` has delegated to
     * @param account The address to return the delegatee for
     * @return The address of the account which `account` delegated to. If `account` has not delegated, returns address(0).
     */
    function delegates(address account) internal view returns (address) {
        DelegateStorage storage ds = delegateStorage();
        return ds.delegates[account];
    }

    /**
     * @notice Creates a new voter checkpoint and updates the delegatee's count of checkpoints
     * @dev this function emits a DelegateVotesChanged event
     * @param delegatee The address of the delegatee to create a checkpoint for
     * @param oldVotes The number of votes the delegatee had prior to the checkpoint
     * @param newVotes The number of votes the delegatee has after the checkpoint
     */
    function writeCheckpoint(address delegatee, uint256 oldVotes, uint256 newVotes) internal {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 checkpointCount = cs.voterCheckpointsCount[delegatee];
        cs.voterCheckpoints[delegatee][checkpointCount] = Checkpoint(block.timestamp, newVotes);
        cs.voterCheckpointsCount[delegatee] = checkpointCount + 1;
        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    /**
     * @notice Creates a new supply checkpoint and updates the count of supply checkpoints
     * @param newSupply The new total supply
     */
    function writeSupplyCheckpoint(uint256 newSupply) internal {
        CheckpointStorage storage cs = checkpointStorage();
        uint32 checkpointCount = cs.supplyCheckpointsCount;
        cs.supplyCheckpoints[checkpointCount] = Checkpoint(block.timestamp, newSupply);
        cs.supplyCheckpointsCount = checkpointCount + 1;
    }

    /**
     * @notice Moves the delegated voting weight from one delegatee to another
     * @dev because it calls writeCheckpoint, as a side effect, a DelegateVotesChanged event is emitted
     * @param oldDelegate The address of the delegatee to remove voting units from. If not address(0), then the voting units are removed from the oldDelegate
     * @param newDelegate The address of the delegatee to add voting units to. If not address(0), then the voting units are added to the newDelegate
     * @param amount The number of voting units to move
     */
    function moveDelegation(address oldDelegate, address newDelegate, uint256 amount) internal {
        if (oldDelegate != newDelegate && amount > 0) {
            if (oldDelegate != address(0)) {
                // decrease old delegatee
                uint256 oldVotes = getVotes(oldDelegate);
                uint256 newVotes = oldVotes - amount;
                writeCheckpoint(oldDelegate, oldVotes, newVotes);
            }

            if (newDelegate != address(0)) {
                // increase new delegatee
                uint256 oldVotes = getVotes(newDelegate);
                uint256 newVotes = oldVotes + amount;
                writeCheckpoint(newDelegate, oldVotes, newVotes);
            }
        }
    }

    /**
     * @notice Moves voting units from one account to another
     * @dev this function potentially updates the total supply when burning or minting, and emits a DelegateVotesChanged event
     * @param from The address of the account to remove voting units from
     * @param to The address of the account to add voting units to
     * @param amount The number of voting units to move
     */
    function transferVotingUnits(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            writeSupplyCheckpoint(getTotalSupply() + amount);
        }
        if (to == address(0)) {
            writeSupplyCheckpoint(getTotalSupply() - amount);
        }
        moveDelegation(delegates(from), delegates(to), amount);
    }

    /**
     * @dev Internal function to delegate voting power from one account to another
     * @param delegator The address delegating their voting power
     * @param delegatee The address receiving the voting power
     * @dev this function emits a DelegateChanged event
     */
    function delegate(address delegator, address delegatee) internal {
        DelegateStorage storage ds = delegateStorage();
        address currentDelegate = ds.delegates[delegator];
        require(delegatee != currentDelegate, "Delegate: already delegated to this delegatee");
        ds.delegates[delegator] = delegatee;
        emit DelegateChanged(delegator, currentDelegate, delegatee);
    }

    /**
     * @dev Internal function to clear the delegation of a delegator
     * @param delegator The address delegating their voting power
     * @dev this function emits a DelegateChanged event
     */
    function clearDelegation(address delegator) internal {
        DelegateStorage storage ds = delegateStorage();
        address currentDelegate = ds.delegates[delegator];
        ds.delegates[delegator] = address(0);
        emit DelegateChanged(delegator, currentDelegate, address(0));
    }
}
