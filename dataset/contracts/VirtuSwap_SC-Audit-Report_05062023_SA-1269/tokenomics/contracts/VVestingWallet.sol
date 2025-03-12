// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VestingWallet
 * @dev This contract is a part of OpenZeppelin's VestingWallet contract. It handles the vesting of VRSW token for a given beneficiary.
 * The contract will release the token to the beneficiary following a given vesting schedule.
 * The vesting schedule is customizable through the {vestedAmount} function.
 */
contract vVestingWallet {
    event ERC20Released(address indexed token, uint256 amount);

    // number of tokens already released
    uint256 private _erc20Released;

    // beneficiary address
    address private immutable _beneficiary;

    // VRSW token address
    address private immutable _erc20Token;

    // start of vesting timestamp
    uint64 private immutable _start;

    // duration of vesting
    uint64 private immutable _duration;

    /**
     * @dev Set the beneficiary, start timestamp, VRSW address and vesting duration of the vesting wallet.
     */
    constructor(
        address beneficiaryAddress,
        address erc20Token,
        uint64 startTimestamp,
        uint64 durationSeconds
    ) {
        require(
            beneficiaryAddress != address(0),
            "vVestingWallet: beneficiary is zero address"
        );
        require(
            erc20Token != address(0),
            "vVestingWallet: erc20Token is zero address"
        );
        require(
            startTimestamp >= block.timestamp,
            "vVestingWallet: start couldn't be in the past"
        );
        require(
            durationSeconds > 0,
            "vVestingWallet: duration must be positive"
        );
        _erc20Token = erc20Token;
        _beneficiary = beneficiaryAddress;
        _start = startTimestamp;
        _duration = durationSeconds;
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release() external {
        require(msg.sender == beneficiary(), "only beneficiary");
        uint256 amount = releasable();
        _erc20Released += amount;
        emit ERC20Released(_erc20Token, amount);
        SafeERC20.safeTransfer(IERC20(_erc20Token), beneficiary(), amount);
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
     * @dev Amount of VRSW already released
     */
    function released() public view returns (uint256) {
        return _erc20Released;
    }

    /**
     * @dev Getter for the amount of releasable VRSW.
     */
    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Calculates the amount of VRSW that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        return
            _vestingSchedule(
                IERC20(_erc20Token).balanceOf(address(this)) + released(),
                timestamp
            );
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time.
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }
}
