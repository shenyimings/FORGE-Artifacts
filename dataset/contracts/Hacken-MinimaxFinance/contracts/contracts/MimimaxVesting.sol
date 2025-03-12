// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract MinimaxVesting is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Released(address token, uint256 amount);

    mapping(address => uint256) private _bep20Released;
    address private _beneficiary;
    uint64 private _start;
    uint64 private _duration;
    uint64 private _batches;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    function initialize(
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 batchesNum
    ) public initializer {
        require(beneficiaryAddress != address(0), "MinimaxVesting: beneficiary is zero address");
        require(batchesNum > 0, "MinimaxVesting: batches is zero");

        OwnableUpgradeable.__Ownable_init();

        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _duration = durationSeconds;
        _batches = batchesNum;
    }

    /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the vesting batches number.
     */
    function batches() public view returns (uint256) {
        return _batches;
    }

    /**
     * @dev Amount of token already released
     */
    function released(address token) public view returns (uint256) {
        return _bep20Released[token];
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {Released} event.
     */
    function release(address token) public {
        uint256 releasable = vestedAmount(token, uint64(block.timestamp)) - released(token);
        _bep20Released[token] += releasable;
        emit Released(token, releasable);
        if (releasable > 0) {
            IERC20Upgradeable(token).safeTransfer(beneficiary(), releasable);
        }
    }

    /**
     * @dev Calculates the amount of tokens that has already vested.
     * Default implementation is a batching vesting strategy.
     */
    function vestedAmount(address token, uint64 timestamp) public view returns (uint256) {
        return _vestingSchedule(IERC20Upgradeable(token).balanceOf(address(this)) + released(token), timestamp);
    }

    /**
     * @dev Implementation of the vesting formula.
     * This returns the amout vested, as a function of time,
     * for an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= start() + duration()) {
            return totalAllocation;
        } else {
            uint64 timeDiff = timestamp - uint64(start());
            uint64 totalBatchesPassed = uint64((uint256(timeDiff) * batches()) / duration());
            return (totalAllocation / batches()) * totalBatchesPassed;
        }
    }
}
