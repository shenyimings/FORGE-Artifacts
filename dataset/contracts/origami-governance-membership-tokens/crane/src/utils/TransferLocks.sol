// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {ITransferLocks} from "src/interfaces/ITransferLocks.sol";
import {ERC20Base} from "src/token/governance/ERC20Base.sol";
import {TransferLocksStorage} from "src/utils/TransferLocksStorage.sol";
import {IERC165} from "@diamond/interfaces/IERC165.sol";

/**
 * @title TransferLocks
 * @author Origami
 * @notice this library enables time-locked transfers of ERC20 tokens.
 * Transferlocks are the inverse of a vesting schedule. They allow the holder to
 * vote with their weight but not to transfer them before a certain date.
 * @dev TransferLocks are resilient to timestamp manipulation by using
 * block.timestamp, locks will typically be measured in months, not seconds.
 * @custom:security-contact contract-security@joinorigami.com
 */
contract TransferLocks is ERC20Base, IERC165, ITransferLocks {
    /// @inheritdoc ITransferLocks
    function addTransferLock(uint256 amount, uint256 deadline) public whenValidLock(amount, deadline) {
        TransferLocksStorage.addTransferLock(msg.sender, amount, deadline);
    }

    /// @inheritdoc ITransferLocks
    function allowances(address account, address recipient) public view returns (uint8) {
        return TransferLocksStorage.allowances(account, recipient);
    }

    /// @inheritdoc ITransferLocks
    function increaseTransferLockAllowance(address account, uint8 amount) public {
        require(account != msg.sender, "TransferLock: accounts do not need to approve themselves");
        TransferLocksStorage.increaseAllowances(msg.sender, account, amount);
    }

    /// @inheritdoc ITransferLocks
    function decreaseTransferLockAllowance(address account, uint8 amount) public {
        require(account != msg.sender, "TransferLock: accounts do not need to approve themselves");
        TransferLocksStorage.decreaseAllowances(msg.sender, account, amount);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotal(address account) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, block.timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getTransferLockTotalAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        return TransferLocksStorage.getTotalLockedAt(account, timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getAvailableBalance(address account) public view returns (uint256 amount) {
        return getAvailableBalanceAt(account, block.timestamp);
    }

    /// @inheritdoc ITransferLocks
    function getAvailableBalanceAt(address account, uint256 timestamp) public view returns (uint256 amount) {
        uint256 totalLocked = TransferLocksStorage.getTotalLockedAt(account, timestamp);
        return balanceOf(account) - totalLocked;
    }

    /// @dev Override ERC20Upgradeable._beforeTokenTransfer to check for transfer locks.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        uint256 lockedAmount = getTransferLockTotal(from);
        // slither-disable-next-line timestamp
        if (lockedAmount > 0 && balanceOf(from) >= amount) {
            // slither-disable-next-line timestamp
            require(balanceOf(from) - amount >= lockedAmount, "TransferLock: this exceeds your unlocked balance");
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    /// @inheritdoc ITransferLocks
    function transferWithLock(address recipient, uint256 amount, uint256 deadline)
        public
        whenValidLock(amount, deadline)
    {
        require(recipient != address(0) && recipient != msg.sender, "TransferLock: invalid recipient");
        TransferLocksStorage.decreaseAllowances(recipient, msg.sender, 1);
        _transfer(msg.sender, recipient, amount);
        TransferLocksStorage.addTransferLock(recipient, amount, deadline);
    }

    /// @inheritdoc ITransferLocks
    function batchTransferWithLocks(
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint256[] calldata deadlines
    ) external {
        require(recipients.length == amounts.length, "TransferLock: recipients and amounts must be the same length");
        require(recipients.length == deadlines.length, "TransferLock: recipients and deadlines must be the same length");
        for (uint256 i = 0; i < recipients.length; i++) {
            transferWithLock(recipients[i], amounts[i], deadlines[i]);
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC20Base, IERC165) returns (bool) {
        return interfaceId == type(ITransferLocks).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Modifier to check that the deadline is in the future and the amount is not greater than the available balance.
    modifier whenValidLock(uint256 amount, uint256 deadline) {
        // slither-disable-next-line timestamp
        require(amount > 0, "TransferLock: amount must be greater than zero");
        require(deadline > block.timestamp, "TransferLock: deadline must be in the future");
        require(
            amount <= getAvailableBalanceAt(msg.sender, block.timestamp),
            "TransferLock: amount cannot exceed available balance"
        );
        _;
    }
}
