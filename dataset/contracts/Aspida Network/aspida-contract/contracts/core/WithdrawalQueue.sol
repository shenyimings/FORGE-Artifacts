// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../library/TransferHelper.sol";

/**
 * @title Aspida's WithdrawalQueue model
 * @dev This contract implements a withdrawal queue for users to withdraw their funds in a fair manner.
 * Users can withdraw their funds immediately if there are enough funds available, otherwise they will be added to the queue.
 * The queue is processed in a first-in-first-out (FIFO) manner.
 * Users can claim their funds from the queue at any time.
 * @author Aspida engineer
 */
abstract contract WithdrawalQueue {
    using EnumerableSet for EnumerableSet.UintSet;
    using TransferHelper for address;

    uint256 internal totalWithdrawn_; // Total amount of funds withdrawn
    uint256 internal totalClaimed_; // Total amount of funds claimed
    uint256 internal pendingClaimAmount_; // Total amount of funds in the queue

    uint256 internal lastQueueId_; // The last queue ID
    mapping(address => EnumerableSet.UintSet) internal userQueueIds_; // Mapping of user addresses to their queue IDs
    struct Claim {
        uint256 amount; // The amount of funds in the queue
        uint256 accumulated; // The accumulated amount of funds in the queue
    }
    mapping(uint256 => Claim) internal claims_; // Mapping of queue IDs to their claim data

    /**
     * @dev Emitted when the total amount of funds in the queue is updated.
     */
    event UpdatePendingClaim(uint256 pendingClaimAmount);

    /**
     * @dev Emitted when the total amount of funds claimed is updated.
     */
    event UpdateTotalClaimed(uint256 totalClaimed);

    /**
     * @dev Emitted when a user is added to the withdrawal queue.
     */
    event EnterWithdrawalQueue(
        address sender,
        address recipient,
        uint256 queueId,
        uint256 claimAmount,
        uint256 accumulated
    );

    /**
     * @dev Emitted when a user is removed from the withdrawal queue.
     */
    event ExitWithdrawalQueue(address sender, address recipient, uint256 queueId, uint256 claimAmount);

    /**
     * @dev Emitted when funds are withdrawn from the contract.
     */
    event Withdrawn(address sender, address recipient, uint256 amount);

    /**
     * @dev Emitted when funds are claimed from the queue.
     */
    event Claimed(address sender, address recipient, uint256 amount);

    /**
     * @dev Updates the total amount of funds in the queue.
     * @param _pendingClaimAmount The new total amount of funds in the queue.
     */
    function _updatePendingClaim(uint256 _pendingClaimAmount) internal {
        pendingClaimAmount_ = _pendingClaimAmount;
        emit UpdatePendingClaim(_pendingClaimAmount);
    }

    /**
     * @dev Updates the total amount of funds claimed.
     * @param _totalClaimed The new total amount of funds claimed.
     */
    function _updateTotalClaimed(uint256 _totalClaimed) internal {
        totalClaimed_ = _totalClaimed;
        emit UpdateTotalClaimed(_totalClaimed);
    }

    /**
     * @dev Adds the user to the withdrawal queue.
     * @param _receiver The address of the user to add to the queue.
     * @param _amount The amount of funds to add to the queue.
     */
    function _withdrawalQueue(address _receiver, uint256 _amount) internal {
        uint256 _queueId = lastQueueId_;
        uint256 _accumulated = claims_[_queueId].accumulated;

        _queueId += 1;
        require(userQueueIds_[_receiver].add(_queueId), "_withdrawalQueue: Queue id already exists");

        Claim storage _claimData = claims_[_queueId];
        _claimData.amount = _amount;
        _claimData.accumulated = _accumulated + _amount;

        lastQueueId_ = _queueId;
        _updatePendingClaim(pendingClaimAmount_ + _amount);
        emit EnterWithdrawalQueue(msg.sender, _receiver, _queueId, _claimData.amount, _claimData.accumulated);
    }

    /**
     * @dev Withdraws funds from the contract.
     * @param _sender The address of the user withdrawing the funds.
     * @param _receiver The address of the user receiving the funds.
     * @param _amount The amount of funds to withdraw.
     */
    function _withdraw(address _sender, address _receiver, uint256 _amount) internal virtual {
        require(_amount > 0, "_withdraw: withdraw amount cannot be 0");
        if (_withdrawableAmount() < _amount) {
            _withdrawalQueue(_receiver, _amount);
            return;
        }

        totalWithdrawn_ += _amount;
        _receiver.safeTransferETH(_amount);
        emit Withdrawn(_sender, _receiver, _amount);
    }

    /**
     * @dev Claims funds from the queue for a specific user.
     * @param _sender The address of the user claiming the funds.
     * @param _receiver The address of the user receiving the funds.
     */
    function _claimByAddress(address _sender, address _receiver) internal virtual {
        EnumerableSet.UintSet storage _userQueueIds = userQueueIds_[_sender];
        _claimByQueueId(_sender, _receiver, _userQueueIds.values(), _userQueueIds);
    }

    /**
     * @dev Claims funds from the queue for a specific user and queue IDs.
     * @param _sender The address of the user claiming the funds.
     * @param _receiver The address of the user receiving the funds.
     * @param _queueIds The list of queue IDs to claim from.
     * @param _userQueueIds The user's queue IDs.
     */
    function _claimByQueueId(
        address _sender,
        address _receiver,
        uint256[] memory _queueIds,
        EnumerableSet.UintSet storage _userQueueIds
    ) internal virtual {
        require(_queueIds.length > 0, "_claimByQueueId: Queue list cannot be empty");

        uint256 _availableBalance = _claimableAmount();
        uint256 _claimAmount;
        for (uint256 i = 0; i < _queueIds.length; i++) {
            uint256 _amount = _getClaimAmount(_queueIds[i], _availableBalance);
            if (_amount == 0) continue;

            require(_userQueueIds.remove(_queueIds[i]), "_claimByQueueId: Queue id does not exist");
            emit ExitWithdrawalQueue(_sender, _receiver, _queueIds[i], _amount);

            _claimAmount += _amount;
        }

        require(_claimAmount > 0, "_claimByQueueId: No claim amount");

        _updatePendingClaim(pendingClaimAmount_ - _claimAmount);
        _updateTotalClaimed(totalClaimed_ + _claimAmount);

        _receiver.safeTransferETH(_claimAmount);
        emit Claimed(_sender, _receiver, _claimAmount);
    }

    /**
     * @dev Returns the amount of funds that can be withdrawn.
     * @return _availableAmount The available amount of funds that can be withdrawn.
     */
    function _withdrawableAmount() internal view virtual returns (uint256 _availableAmount) {
        uint256 _balance = address(this).balance;
        uint256 _locked = pendingClaimAmount_;
        if (_balance > _locked) _availableAmount = _balance - _locked;
    }

    /**
     * @dev Returns the amount of funds that can be claimed.
     * @return _claimableAmount The claimable amount of funds.
     */
    function _claimableAmount() internal view virtual returns (uint256) {
        return address(this).balance + totalClaimed_;
    }

    /**
     * @dev Returns the claim amount for a specific queue ID.
     * @param _queueId The queue ID.
     * @param _claimable The claimable amount of funds.
     * @return _claimAmount The claim amount for the queue ID.
     */
    function _getClaimAmount(uint256 _queueId, uint256 _claimable) internal view returns (uint256 _claimAmount) {
        Claim storage _claimData = claims_[_queueId];
        if (_claimable >= _claimData.accumulated) _claimAmount = _claimData.amount;
    }

    /**
     * @dev Allows a user to withdraw funds.
     * @param _amount The amount of funds to withdraw.
     */
    function withdraw(uint256 _amount) external {
        _withdraw(msg.sender, msg.sender, _amount);
    }

    /**
     * @dev Allows a user to withdraw funds and specify a receiver address.
     * @param _amount The amount of funds to withdraw.
     * @param _receiver The address of the receiver.
     */
    function withdraw(uint256 _amount, address _receiver) external {
        _withdraw(msg.sender, _receiver, _amount);
    }

    /**
     * @dev Allows a user to claim their funds from the queue.
     */
    function claim() external {
        _claimByAddress(msg.sender, msg.sender);
    }

    /**
     * @dev Allows a user to claim their funds from the queue and specify a receiver address.
     * @param _receiver The address of the receiver.
     */
    function claim(address _receiver) external {
        _claimByAddress(msg.sender, _receiver);
    }

    /**
     * @dev Allows a user to claim their funds from the queue using specific queue IDs.
     * @param _queueIds The list of queue IDs to claim from.
     */
    function claim(uint256[] memory _queueIds) external {
        _claimByQueueId(msg.sender, msg.sender, _queueIds, userQueueIds_[msg.sender]);
    }

    /**
     * @dev Allows a user to claim their funds from the queue using specific queue IDs and specify a receiver address.
     * @param _receiver The address of the receiver.
     * @param _queueIds The list of queue IDs to claim from.
     */
    function claim(address _receiver, uint256[] memory _queueIds) external {
        _claimByQueueId(msg.sender, _receiver, _queueIds, userQueueIds_[msg.sender]);
    }

    /**
     * @dev Returns the total amount of funds withdrawn.
     * @return The total amount of funds withdrawn.
     */
    function totalWithdrawn() external view returns (uint256) {
        return totalWithdrawn_;
    }

    /**
     * @dev Returns the total amount of funds claimed.
     * @return The total amount of funds claimed.
     */
    function totalClaimed() external view returns (uint256) {
        return totalClaimed_;
    }

    /**
     * @dev Returns the total amount of funds in the queue.
     * @return The total amount of funds in the queue.
     */
    function pendingClaimAmount() external view returns (uint256) {
        return pendingClaimAmount_;
    }

    /**
     * @dev Returns the last queue ID.
     * @return The last queue ID.
     */
    function lastQueueId() external view returns (uint256) {
        return lastQueueId_;
    }

    /**
     * @dev Returns the accumulated amount of funds in the queue.
     * @return The accumulated amount of funds in the queue.
     */
    function accumulated() external view returns (uint256) {
        return claims_[lastQueueId_].accumulated;
    }

    /**
     * @dev Returns the amount of funds that can be withdrawn.
     * @return The amount of funds that can be withdrawn.
     */
    function withdrawableAmount() external view returns (uint256) {
        return _withdrawableAmount();
    }

    /**
     * @dev Returns the amount of funds that can be claimed.
     * @return The amount of funds that can be claimed.
     */
    function claimableAmount() external view returns (uint256) {
        return _claimableAmount();
    }

    /**
     * @dev Returns the claim data for a specific queue ID.
     * @param _queueId The queue ID.
     * @return The claim data for the queue ID.
     */
    function claimData(uint256 _queueId) external view returns (Claim memory) {
        return claims_[_queueId];
    }

    /**
     * @dev Returns the claim data for a specific address.
     * @param _account The address to get claim data for.
     * @return _ids The IDs of the claims.
     * @return _claimAmounts The amounts of the claims.
     * @return _claimStatuses The statuses of the claims.
     */
    function claimDataByAddress(
        address _account
    ) external view returns (uint256[] memory _ids, uint256[] memory _claimAmounts, bool[] memory _claimStatuses) {
        _ids = userQueueIds_[_account].values();
        _claimAmounts = new uint256[](_ids.length);
        _claimStatuses = new bool[](_ids.length);

        uint256 _claimable = _claimableAmount();
        for (uint256 i = 0; i < _ids.length; i++) {
            _claimAmounts[i] = claims_[_ids[i]].amount;
            _claimStatuses[i] = _claimable >= claims_[_ids[i]].accumulated;
        }
    }

    /**
     * @dev Returns the queue IDs and claim data for a specific user.
     * @param _account The address of the user.
     * @return _ids The IDs of the user's claims.
     * @return _claimData The claim data for each of the user's claims.
     */
    function userQueueIds(address _account) external view returns (uint256[] memory _ids, Claim[] memory _claimData) {
        _ids = userQueueIds_[_account].values();
        _claimData = new Claim[](_ids.length);
        for (uint256 i = 0; i < _claimData.length; i++) {
            _claimData[i] = claims_[_ids[i]];
        }
    }
}
