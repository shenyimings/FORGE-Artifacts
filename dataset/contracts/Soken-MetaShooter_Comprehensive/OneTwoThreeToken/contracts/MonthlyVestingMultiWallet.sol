// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.3.2 (finance/VestingWallet.sol)
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MonthlyVestingMultiWallet is  Ownable {
    event EtherReleased(uint256 amount);
    event ERC20Released(address token, uint256 amount);

    mapping(address => uint256) public _released;
    mapping(address => uint256) public beneficiaries;
    address[] public beneficiariesAddresses;

    uint64 private immutable _start;
    address public immutable token;
    uint64 private immutable _duration;
    uint64 private immutable _durationMonths;
    uint64 private immutable _cliffDurationMonths;
    uint64 private immutable _cliff;
    uint64 private immutable _initialMintingPercent;

    uint64 constant internal SECONDS_PER_MONTH = 2628288;

    /**
     * @dev Set the beneficiary, start timestamp and vesting duration of the vesting wallet.
     */
    constructor(
        address tokenAddress,
        uint64 startTimestamp,
        uint64 cliffDurationMonths,
        uint64 durationMonths,
        uint64 initialMintingPercent)
    {
        token = tokenAddress;
        _start = startTimestamp;
        _durationMonths = durationMonths+1;
        _cliffDurationMonths = cliffDurationMonths;
        _duration = durationMonths * SECONDS_PER_MONTH;
        _cliff = _cliffDurationMonths * SECONDS_PER_MONTH;
        _initialMintingPercent = initialMintingPercent;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the beneficiaries count
     */
    function getBeneficiariesCount() public view returns (uint) {
        return beneficiariesAddresses.length;
    }

    /**
     * @dev Getter for the beneficiaries count
     */
    function buy(address user, uint256 amount) public virtual onlyOwner{
        if (beneficiaries[user] == 0){
            beneficiariesAddresses.push(user);
        }
        beneficiaries[user] += amount;

    }

    /**
     * @dev Amount of tokens already released
     */
    function released(address user) public view virtual returns (uint256) {
        return _released[user];
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function release(address user) public virtual returns (uint256) {
        uint256 releasable = vestedAmount(user, uint64(block.timestamp)) - released(user);
        require(releasable > 0, "MonthlyVestingMultiWallet: no funds to release");
        _released[user] += releasable;
        emit ERC20Released(token, releasable);
        SafeERC20.safeTransfer(IERC20(token), user, releasable);
        return releasable;
    }

    /**
     * @dev Release all tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function releaseAll(uint256 offset, uint256 length) public virtual{
        if (length == 0) {
            length = beneficiariesAddresses.length + offset;
        }

        for (uint256 i = offset; i < length; i++) {
            uint256 releasable = vestedAmount(beneficiariesAddresses[i], uint64(block.timestamp)) - released(beneficiariesAddresses[i]);
            if (releasable > 0){
                release(beneficiariesAddresses[i]);
            }
        }
    }

    /**
     * @dev Calculates the amount of tokens that has already vested.
     */
    function vestedAmount(address user, uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(beneficiaries[user], timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        return totalAllocation * equalMonthlyVestingPercent(timestamp) / 10000;
    }

    /**
     * @dev Calculates the percentage of tokens that has already vested as a function of time.
     */
    function equalMonthlyVestingPercent(uint64 timestamp) public view returns (uint64) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp - start() < _cliff)  {
            return _initialMintingPercent * 100;
        } else if (timestamp > start() + duration()) {
            return 10000;
        }
        uint64 secondsAfterCliff = timestamp - _start - _cliff;
        uint64 step = (10000 / _durationMonths);
        return ((step + (secondsAfterCliff * 10000 /  SECONDS_PER_MONTH /  _durationMonths)) / step * step) + _initialMintingPercent * 100;
    }


}