// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title Transfer Locks Storage Library
 * @author Origami
 * @notice This library is used to store transfer locks for the Origami Governance Token.
 * @custom:security-contact contract-security@joinorigami.com
 */
library TransferLocksStorage {
    bytes32 public constant TRANSFER_LOCKS_STORAGE_POSITION = keccak256("com.origami.transferlocks");
    uint8 public constant MAX_LOCKS_PER_ACCOUNT = type(uint8).max;

    /// @dev storage data structure for transfer locks
    struct TransferLock {
        uint256 amount;
        uint256 deadline;
        uint256 next;
        uint256 prev;
    }

    /// @dev address mapping for transfer locks
    struct TransferLocks {
        mapping(address => mapping(uint256 => TransferLock)) locks;
        mapping(address => mapping(address => uint8)) allowances;
        mapping(address => uint8) numLocks;
        mapping(address => uint8) numAllowances;
        mapping(address => uint8) firstLock;
        mapping(address => uint8) lastLock;
    }

    function increaseAllowances(address account, address recipient, uint8 amount) internal {
        TransferLocks storage tls = transferLocksStorage();
        require(
            MAX_LOCKS_PER_ACCOUNT - amount >= tls.numLocks[account] + tls.numAllowances[account],
            "TransferLocks: cannot exceed max account locks and allowances"
        );
        tls.numAllowances[account] += amount;
        tls.allowances[account][recipient] += amount;
    }

    function decreaseAllowances(address account, address recipient, uint8 amount) internal {
        TransferLocks storage tls = transferLocksStorage();
        require(tls.allowances[account][recipient] >= amount, "TransferLocks: insufficient allowance");
        tls.numAllowances[account] -= amount;
        tls.allowances[account][recipient] -= amount;
    }

    function allowances(address account, address recipient) internal view returns (uint8) {
        TransferLocks storage tls = transferLocksStorage();
        return tls.allowances[account][recipient];
    }

    /// @dev returns the storage pointer for transfer locks
    function transferLocksStorage() internal pure returns (TransferLocks storage tls) {
        bytes32 position = TRANSFER_LOCKS_STORAGE_POSITION;
        // solhint-disable no-inline-assembly
        // slither-disable-next-line assembly
        assembly {
            tls.slot := position
        }
        // solhint-enable no-inline-assembly
    }

    /**
     * @notice adds a transfer lock to an account
     * @param account the account to add the transfer lock to
     * @param amount the amount of tokens to lock
     * @param deadline the timestamp after which the lock expires
     * Regarding slither disable timestamp: Block manipulation generally occurs over
     * a very short period of time (seconds/minutes). In this case, any manipulation of
     * block-timestamp would affect the expiration of transfer locks for accounts.
     * This could cause a transfer lock to expire slightly earlier or later than intended.
     * However, the impact is limited, and the overall functioning of the contract is not
     * severely affected.
     */
    function addTransferLock(address account, uint256 amount, uint256 deadline) internal {
        TransferLocks storage tls = transferLocksStorage();

        // Remove expired locks from the head of the linked list
        // slither-disable-next-line timestamp
        while (tls.numLocks[account] > 0 && tls.locks[account][tls.firstLock[account]].deadline < block.timestamp) {
            // Delete the expired lock from storage
            delete tls.locks[account][tls.firstLock[account]];
            // Increment the index of the first lock in the list
            tls.firstLock[account] += 1;
            // Decrement the number of locks
            tls.numLocks[account] -= 1;
        }

        // Make sure we haven't exceeded the maximum number of locks
        require(
            MAX_LOCKS_PER_ACCOUNT - 1 >= tls.numLocks[account] + tls.numAllowances[account],
            "TransferLocks: cannot exceed max account locks and allowances"
        );

        // Get the index of the new lock
        uint8 index = tls.numLocks[account];

        // Create the new lock and add it to storage
        tls.locks[account][index] = TransferLock(amount, deadline, 0, 0);

        // If this is the first lock, update the first and last lock indices
        if (index == 0) {
            tls.firstLock[account] = 0;
            tls.lastLock[account] = 0;
        } else {
            // If this is not the first lock, update the next and prev pointers of the locks
            // Update the prev pointer of the new lock to point to the last lock in the list
            tls.locks[account][index].prev = tls.lastLock[account];
            // Update the next pointer of the last lock in the list to point to the new lock
            tls.locks[account][tls.lastLock[account]].next = index;
            // Update the last lock index to point to the new lock
            tls.lastLock[account] = index;
        }

        // Increment the number of locks
        tls.numLocks[account] += 1;
    }

    /**
     * @notice returns the total amount of tokens locked for an account as of a given timestamp
     * @param account the account to check
     * @param timestamp the timestamp to check
     * @return the total amount of tokens locked for an account at the given timestamp
     */
    function getTotalLockedAt(address account, uint256 timestamp) internal view returns (uint256) {
        TransferLocks storage tls = transferLocksStorage();
        uint256 totalLocked = 0;

        // Iterate over the linked list of transfer locks and add up the amount of tokens that are locked
        for (uint256 i = tls.firstLock[account]; i <= tls.lastLock[account]; i++) {
            if (tls.locks[account][i].deadline >= timestamp) {
                totalLocked += tls.locks[account][i].amount;
            }
        }

        return totalLocked;
    }
}
