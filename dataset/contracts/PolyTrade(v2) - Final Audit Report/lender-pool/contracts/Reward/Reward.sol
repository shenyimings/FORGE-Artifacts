//SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import "./interface/IReward.sol";
import "../Token/interface/IToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Polytrade
 * @title Reward V2
 */
contract Reward is IReward, AccessControl {
    using SafeERC20 for IToken;

    bytes32 public constant REWARD_MANAGER = keccak256("REWARD_MANAGER");
    bytes32 public constant OWNER = keccak256("OWNER");

    mapping(address => Lender) private _lender;
    mapping(uint16 => RoundInfo) public round;

    uint16 public currentRound = 0;

    IToken private _rewardToken;

    constructor(address _address) {
        require(_address != address(0), "Invalid address");
        _rewardToken = IToken(_address);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice `registerUser` registers user to the `Reward`
     * @dev Gets the lender info from previous `RewardManager`
     * @param lender, address of the lender
     * @param deposited, amount deposit by the lender
     * @param startPeriod, start period of the
     */
    function registerUser(
        address lender,
        uint deposited,
        uint40 startPeriod
    ) external onlyRole(REWARD_MANAGER) {
        require(lender != address(0), "Should not be address(0)");
        require(!_lender[lender].registered, "User already registered");
        _lender[lender].deposit = deposited;
        _lender[lender].registered = true;
        _lender[lender].startPeriod = startPeriod;
    }

    /**
     * @notice `setReward` updates the value of reward.
     * @dev For example - APY in case of tStable, trade per year per stable in case of trade reward.
     * @dev It can only be called by OWNER role.
     * @param newReward, current reward offered by the contract.
     *
     * Emits {NewReward} event
     */
    function setReward(uint16 newReward) external onlyRole(OWNER) {
        require(newReward > 0, "Should be higher than 0");
        _setReward(newReward);
    }

    /**
     * @notice `pauseReward` sets the apy to 0.
     * @dev It is called after `RewardManager` is discontinued.
     * @dev It can be called by only REWARD_MANAGER.
     */
    function resetReward() external onlyRole(REWARD_MANAGER) {
        _setReward(0);
    }

    /**
     * @notice `deposit` increases the `lender` deposit by `amount`
     * @dev It can only be called by the REWARD_MANAGER.
     * @param lender, address of the lender
     * @param amount, amount deposited by lender
     *
     * Requirements:
     * - `amount` should be greater than 0
     *
     */
    function deposit(address lender, uint amount)
        external
        onlyRole(REWARD_MANAGER)
    {
        require(amount > 0, "Lending amount is 0");
        require(lender != address(0), "Should not be address(0)");
        if (_lender[lender].startPeriod > 0) {
            _updatePendingReward(lender);
        } else {
            _lender[lender].startPeriod = uint40(block.timestamp);
        }

        _lender[lender].deposit += amount;
        _lender[lender].round = currentRound;
    }

    /**
     * @notice `withdraw` withdraws the `amount` from `lender`
     * @dev It can only be called by the REWARD_MANAGER.
     * @param lender, address of the lender
     * @param amount, amount requested by lender
     *
     * - `amount` should be greater than 0
     * - `amount` should be greater than deposited by the lender
     *
     */
    function withdraw(address lender, uint amount)
        external
        onlyRole(REWARD_MANAGER)
    {
        require(amount > 0, "Cannot withdraw 0 amount");
        require(_lender[lender].deposit >= amount, "Invalid amount requested");
        require(lender != address(0), "Should not be address(0)");
        if (currentRound > 0) {
            _updatePendingReward(lender);
        }
        _lender[lender].deposit -= amount;
    }

    /**
     * @notice `claimReward` send reward to lender.
     * @dev It calls `_updatePendingReward` function and sets pending reward to 0.
     * @dev It can only be called by the REWARD_MANAGER.
     * @param lender, address of the lender.
     *
     * Emits {RewardClaimed} event
     */
    function claimReward(address lender) external onlyRole(REWARD_MANAGER) {
        _updatePendingReward(lender);
        uint totalReward = _lender[lender].pendingRewards;
        _lender[lender].pendingRewards = 0;
        _rewardToken.safeTransfer(lender, totalReward);
        emit RewardClaimed(lender, totalReward);
    }

    /**
     * @notice `getReward` returns the total reward.
     * @return returns the total reward.
     */
    function getReward() external view returns (uint16) {
        return round[currentRound].apy;
    }

    /**
     * @notice `getRewardToken` returns the address of the reward token
     * @return address of the reward token
     */
    function getRewardToken() external view returns (address) {
        return address(_rewardToken);
    }

    /**
     * @notice `rewardOf` returns the total pending reward of the lender
     * @dev It calculates reward of lender upto current time.
     * @param lender, address of the lender
     * @return returns the total pending reward
     */
    function rewardOf(address lender) external view returns (uint) {
        if (_lender[lender].round < currentRound) {
            return
                _lender[lender].pendingRewards +
                _calculateFromPreviousRounds(lender);
        } else {
            return
                _lender[lender].pendingRewards + _calculateCurrentRound(lender);
        }
    }

    /**
     * @notice `_updatePendingReward` updates round, pendingRewards and startTime of the lender
     * @dev It compares the lender round with currentRound and updates _lender accordingly
     * @param lender, address of the lender
     */
    function _updatePendingReward(address lender) private {
        if (_lender[lender].round == currentRound) {
            _lender[lender].pendingRewards += _calculateCurrentRound(lender);
        }

        if (_lender[lender].round < currentRound) {
            _lender[lender].pendingRewards += _calculateFromPreviousRounds(
                lender
            );
            _lender[lender].round = currentRound;
        }
        _lender[lender].startPeriod = uint40(block.timestamp);
    }

    /**
     * @notice `_setReward` updates the value of reward.
     * @param newReward, current reward offered by the contract.
     *
     * Emits {NewReward} event
     */
    function _setReward(uint16 newReward) private {
        if (currentRound > 0) {
            round[currentRound].endTime = uint40(block.timestamp);
        }

        currentRound++;

        uint16 oldReward = round[currentRound].apy;
        round[currentRound] = RoundInfo(
            newReward,
            uint40(block.timestamp),
            type(uint40).max
        );

        emit NewReward(oldReward, newReward);
    }

    /**
     * @notice `_calculateCurrentRound` return the total reward when lender round is equal to currentRound
     * @param lender, address of the lender
     * @return returns total pending reward
     */
    function _calculateCurrentRound(address lender)
        private
        view
        returns (uint)
    {
        uint reward = _calculateReward(
            _lender[lender].deposit,
            _max(_lender[lender].startPeriod, round[currentRound].startTime),
            _min(uint40(block.timestamp), round[currentRound].endTime),
            round[currentRound].apy
        );
        return reward;
    }

    /**
     * @notice `_calculateFromPreviousRounds` return the total reward when lender round is less than currentRound
     * @param lender, address of the lender
     * @return returns total pending reward
     */
    function _calculateFromPreviousRounds(address lender)
        private
        view
        returns (uint)
    {
        uint reward = 0;
        for (uint16 i = _lender[lender].round; i <= currentRound; i++) {
            if (i == 0) {
                continue;
            }

            reward += _calculateReward(
                _lender[lender].deposit,
                _max(_lender[lender].startPeriod, round[i].startTime),
                _min(uint40(block.timestamp), round[i].endTime),
                round[i].apy
            );
        }
        return reward;
    }

    /**
     * @notice calculates the reward
     * @dev calculates the reward using the formula given below
     * @param amount, principal amount
     * @param start, start of the tenure for reward
     * @param end, end of the tenure for reward
     * @param reward, value of reward (eg - tradeRate, APY)
     * @return returns reward
     */
    function _calculateReward(
        uint amount,
        uint40 start,
        uint40 end,
        uint16 reward
    ) private pure returns (uint) {
        if (amount == 0 || reward == 0 || start >= end) {
            return 0;
        }
        uint oneYear = (1E4 * 365 days);
        return (((end - start) * reward * amount) / oneYear);
    }

    /**
     * @notice returns maximum among two uint40 variables
     * @dev compares two uint40 variables a and b and return maximum between them
     * @param a, value of uint40 variable
     * @param b, value of uint40 variable
     * @return returns maximum between a and b
     */
    function _max(uint40 a, uint40 b) private pure returns (uint40) {
        return a > b ? a : b;
    }

    /**
     * @notice returns minimum among two uint40 variables
     * @dev compares two uint40 variables a and b and return minimum between them
     * @param a, value of uint40 variable
     * @param b, value of uint40 variable
     * @return returns minimum between a and b
     */
    function _min(uint40 a, uint40 b) private pure returns (uint40) {
        return a > b ? b : a;
    }
}
