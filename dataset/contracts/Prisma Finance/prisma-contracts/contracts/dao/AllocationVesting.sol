// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DelegatedOps } from "../dependencies/DelegatedOps.sol";
import { ITokenLocker } from "../interfaces/ITokenLocker.sol";

/**
 * @title Vesting contract for team and investors
 * @author PrismaFi
 * @notice Vesting contract which allows transfer of future vesting claims
 */
contract AllocationVesting is DelegatedOps {
    error NothingToClaim();
    error AllocationsMismatch();
    error ZeroTotalAllocation();
    error ZeroAllocation();
    error InsufficientPoints();
    error LockedAllocation();

    struct AllocationState {
        uint128 points;
        uint128 claimed;
    }

    // This number should allow a good precision in allocation fractions
    uint256 private constant TOTAL_POINTS = 100000;
    // Precomputed denominator to save gas
    uint256 private constant CLAIMABLE_DENOMINATOR = TOTAL_POINTS * 52 weeks;
    // Users allocations
    mapping(address => AllocationState) public allocations;
    // Total allocation expressed in tokens
    uint256 public immutable totalAllocation;
    // Vesting timeline starting timestamp
    uint256 public immutable vestingStart;
    // Vesting timeline ending timestamp
    uint256 public immutable vestingEnd;
    IERC20 public immutable vestingToken;
    address public immutable treasury;
    ITokenLocker public immutable tokenLocker;
    uint256 public immutable lockToTokenRatio;

    constructor(
        IERC20 vestingToken_,
        ITokenLocker tokenLocker_,
        uint256[] memory allPoints,
        address[] memory recipients,
        uint256 totalAllocation_,
        address treasury_
    ) {
        if (totalAllocation_ == 0) revert ZeroTotalAllocation();
        if (allPoints.length != recipients.length) revert AllocationsMismatch();
        treasury = treasury_;
        tokenLocker = tokenLocker_;
        vestingToken = vestingToken_;
        vestingStart = block.timestamp;
        vestingEnd = block.timestamp + 52 weeks;
        totalAllocation = totalAllocation_;
        uint256 loopEnd = allPoints.length;
        uint256 totalPoints;
        for (uint256 i; i < loopEnd; ) {
            uint256 points = allPoints[i];
            totalPoints += points;
            if (points == 0) revert ZeroAllocation();
            allocations[recipients[i]].points = uint128(points);
            unchecked {
                ++i;
            }
        }
        if (totalPoints != TOTAL_POINTS) revert AllocationsMismatch();
        vestingToken_.approve(address(tokenLocker_), totalAllocation_);
        lockToTokenRatio = tokenLocker_.lockToTokenRatio();
    }

    /**
     * @notice Claims accrued tokens for initiator and transfers a number of allocation points to a recipient
     * @dev Can be delegated
     * @param from Initiator
     * @param to Recipient
     * @param points Number of points to transfer
     */
    function transferPoints(address from, address to, uint256 points) external callerOrDelegated(from) {
        AllocationState memory fromAllocation = allocations[from];
        (uint256 totalVested, ) = _vestedAt(block.timestamp, fromAllocation.points);
        if (totalVested < fromAllocation.claimed) revert LockedAllocation();
        if (points == 0) revert ZeroAllocation();
        if (fromAllocation.points < points) revert InsufficientPoints();
        // We claim one last time before transfer
        uint256 claimed = _claim(from, fromAllocation.points, fromAllocation.claimed);
        // Passive balance to transfer
        uint128 claimedAdjustment = uint128((claimed * points) / fromAllocation.points);

        allocations[from].points = uint128(fromAllocation.points - points);
        allocations[from].claimed = allocations[from].claimed - claimedAdjustment;

        allocations[to].points = allocations[to].points + uint128(points);
        allocations[to].claimed = allocations[to].claimed + claimedAdjustment;
    }

    /**
     * @notice Lock future claimable tokens tokens
     * @dev Can be delegated
     * @param account Account to lock for
     */
    function lockFutureClaims(address account) external callerOrDelegated(account) {
        lockFutureClaimsWithReceiver(account, account);
    }

    /**
     * @notice Lock future claimable tokens tokens
     * @dev Can be delegated
     * @param account Account to lock for
     * @param receiver Receiver of the lock
     */
    function lockFutureClaimsWithReceiver(address account, address receiver) public callerOrDelegated(account) {
        AllocationState memory allocation = allocations[account];
        uint256 claimedUpdated = _claim(account, allocation.points, allocation.claimed);
        (uint256 claimable, uint256 endTime) = _claimableAt(
            block.timestamp + 12 weeks,
            allocation.points,
            claimedUpdated
        );

        if (claimable == 0) revert NothingToClaim();
        claimedUpdated += claimable;
        allocations[account].claimed = uint128(claimedUpdated);
        vestingToken.transferFrom(treasury, address(this), claimable);
        // This can result in -1 week of locking but it's still fair since
        // we already lock for more than the weighted average duration
        uint256 weekLock = (endTime - block.timestamp) / 1 weeks;
        tokenLocker.lock(receiver, claimable / lockToTokenRatio, weekLock);
    }

    /**
     *
     * @notice Claims accrued tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external callerOrDelegated(account) {
        AllocationState memory allocation = allocations[account];
        _claim(account, allocation.points, allocation.claimed);
    }

    // This function exists to avoid reloading the AllocationState struct in memory
    function _claim(address account, uint256 points, uint256 claimed) private returns (uint256 claimedUpdated) {
        if (points == 0) revert NothingToClaim();
        (uint256 claimable, ) = _claimableAt(block.timestamp, points, claimed);
        if (claimable == 0) revert NothingToClaim();
        claimedUpdated = claimed + claimable;
        allocations[account].claimed = uint128(claimedUpdated);
        // We send to delegate for possible zaps
        vestingToken.transferFrom(treasury, msg.sender, claimable);
    }

    /**
     * @notice Calculates number of tokens claimable by the user at the current block
     * @param account Account to calculate for
     * @return claimable Accrued tokens
     */
    function claimableNow(address account) external view returns (uint256 claimable) {
        AllocationState memory allocation = allocations[account];
        (claimable, ) = _claimableAt(block.timestamp, allocation.points, allocation.claimed);
    }

    function _claimableAt(uint256 when, uint256 points, uint256 claimed) private view returns (uint256, uint256) {
        (uint256 totalVested, uint256 endTime) = _vestedAt(when, points);
        return (totalVested > claimed ? totalVested - claimed : 0, endTime);
    }

    function _vestedAt(uint256 when, uint256 points) private view returns (uint256 vested, uint256 endTime) {
        endTime = when >= vestingEnd ? vestingEnd : when;
        uint256 timeSinceStart = endTime - vestingStart;
        vested = (totalAllocation * timeSinceStart * points) / CLAIMABLE_DENOMINATOR;
    }

    /**
     * @notice Calculates the total number of tokens left unclaimed by the user including unvested ones
     * @param account Account to calculate for
     * @return Unclaimed tokens
     */
    function unclaimed(address account) external view returns (uint256) {
        AllocationState memory allocation = allocations[account];
        uint256 accountAllocation = (totalAllocation * allocation.points) / TOTAL_POINTS;
        return accountAllocation - allocation.claimed;
    }
}
