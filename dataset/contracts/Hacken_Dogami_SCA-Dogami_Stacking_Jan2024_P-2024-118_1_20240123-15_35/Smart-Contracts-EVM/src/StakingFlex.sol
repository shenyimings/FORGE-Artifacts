// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

/// @title Flexible Staking contract
contract StakingFlex is Ownable, Pausable, ReentrancyGuard {

    /// @dev Emitted when tokens are staked.
    event TokensStaked(address indexed staker, uint256 amount);

    /// @dev Emitted when a tokens are withdrawn.
    event TokensWithdrawn(address indexed staker, uint256 amount);

    /// @dev Emitted when a staker claims staking rewards.
    event RewardsClaimed(address indexed staker, uint256 rewardAmount);

    /// @dev Emitted when contract admin updates timeUnit.
    event UpdatedTimeUnit(uint256 oldTimeUnit, uint256 newTimeUnit);

    /// @dev Emergency event to force the withdrawals of found
    event TokensWithdrawnAdmin(address indexed staker, uint256 amount);

    /// @dev Emitted when contract admin updates rewardsPerUnitTime.
    event UpdatedRewardRatio(
        uint256 oldNumerator,
        uint256 newNumerator,
        uint256 oldDenominator,
        uint256 newDenominator
    );

    /// @dev Represent a staking condition
    struct StakingCondition {
        uint256 timeUnit;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 rewardRatioNumerator;
        uint256 rewardRatioDenominator;
    }

    /// @dev Represent a staker position
    struct StakerStaking {
        uint256 conditionIdOflastUpdate;
        uint256 timeOfLastUpdate;
        uint256 amountStaked;
        uint256 unclaimedRewards;
    }

    /// @dev Mapping staker address to StakerStaking
    mapping(address => StakerStaking) public stakers;

    /// @dev Total reward collected per Wallet
    mapping(address => uint256) public stakersRewardClaimed;

    /// @dev Address of ERC20 contract of the stacked Tokens
    address public immutable stakingToken;

    /// @dev Decimals of staking token.
    uint256 public immutable stakingTokenDecimals;

    /// @dev Address of ERC20 contract of the reward Tokens
    address public immutable rewardToken;

    /// @dev Decimals of reward token.
    uint256 public immutable rewardTokenDecimals;

    /// @dev Total amount of tokens staked in the contract.
    uint256 public stakingTokenBalance;

    /// @dev Next staking condition Id. Tracks number of conditions updates so far.
    uint256 private nextConditionId;

    /// @dev Address of the wallet holdings the token rewards
    address public immutable rewardWallet;

    /// @dev Count the total number of unique stakers
    uint256 public totalStakers;

    /// @dev Count the total rewards claimed by all the users.
    uint256 public totalRewardClaimed;

    /// @dev Mapping from condition Id to staking condition. See {struct IStaking721.StakingCondition}
    mapping(uint256 => StakingCondition) private stakingConditions;

    /**
    * @notice Initializes a new StakingFlex contract with specific token addresses and staking conditions.
    * @dev Sets up the staking token, reward token, initial staking conditions, and the contract owner.
    *      It fetches token decimals and initializes the first staking condition.
    * @param _stakingToken Address of the ERC20 token used for staking.
    * @param _rewardToken Address of the ERC20 token used for rewards.
    * @param _rewardWallet Address of the wallet holding the reward tokens.
    * @param _timeUnit The initial time unit for reward calculations.
    * @param _numerator The numerator part of the reward ratio for the first staking condition.
    * @param _denominator The denominator part of the reward ratio for the first staking condition, ensuring no division by zero.
    */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _rewardWallet,
        uint80 _timeUnit,
        uint256 _numerator,
        uint256 _denominator
    ) Ownable(msg.sender) {
        require(_rewardWallet != address(this), "Reward wallet cannot be the contract itself");
        require(_stakingToken != address(0) && _rewardToken != address(0) && _rewardWallet != address(0),
            "Staking/Reward token/wallet cannot be the zero address");
        stakingToken = _stakingToken;
        stakingTokenDecimals = IERC20Metadata(_stakingToken).decimals();
        rewardTokenDecimals = IERC20Metadata(_rewardToken).decimals();
        rewardToken = _rewardToken;
        rewardWallet = _rewardWallet;
        _setStakingCondition(_timeUnit, _numerator, _denominator);
    }

    /**
    * @dev Returns the time unit from the latest staking condition.
    * @return _timeUnit The current time unit in seconds for reward calculations.
    */
    function getTimeUnit() public view returns (uint256 _timeUnit) {
        _timeUnit = stakingConditions[nextConditionId - 1].timeUnit;
    }

    /**
    * @dev Returns the numerator and denominator of the reward ratio from the latest staking condition.
    * @return _numerator The numerator part of the current reward ratio.
    * @return _denominator The denominator part of the current reward ratio.
    */
    function getRewardRatio() public view returns (uint256 _numerator, uint256 _denominator) {
        _numerator = stakingConditions[nextConditionId - 1].rewardRatioNumerator;
        _denominator = stakingConditions[nextConditionId - 1].rewardRatioDenominator;
    }

    /**
     *  @notice  Set time unit. Set as a number of seconds.
     *           Could be specified as -- x * 1 hours, x * 1 days, etc.
     *  @dev     Can only be called by the contract owner.
     *  @param _timeUnit    New time unit.
     */
    function setTimeUnit(uint256 _timeUnit) external virtual onlyOwner {

        StakingCondition memory condition = stakingConditions[nextConditionId - 1];
        require(_timeUnit != condition.timeUnit, "Time-unit unchanged.");
        _setStakingCondition(_timeUnit, condition.rewardRatioNumerator, condition.rewardRatioDenominator);

        emit UpdatedTimeUnit(condition.timeUnit, _timeUnit);
    }

    /**
     *  @notice  Set rewards per unit of time.
     *           Interpreted as (numerator/denominator) rewards per second/per day/etc based on time-unit.
     *
     *           For e.g., ratio of 1/20 would mean 1 reward token for every 20 tokens staked.
     *  @dev     Can only be called by the contract owner.
     *  @param _numerator    Reward ratio numerator.
     *  @param _denominator  Reward ratio denominator.
     */
    function setRewardRatio(uint256 _numerator, uint256 _denominator) external virtual onlyOwner {
        StakingCondition memory condition = stakingConditions[nextConditionId - 1];
        require(
            _numerator != condition.rewardRatioNumerator || _denominator != condition.rewardRatioDenominator,
            "Reward ratio unchanged."
        );
        _setStakingCondition(condition.timeUnit, _numerator, _denominator);

        emit UpdatedRewardRatio(
            condition.rewardRatioNumerator,
            _numerator,
            condition.rewardRatioDenominator,
            _denominator
        );
    }

    /**
    * @dev Internal function to set a new staking condition with specified time unit and reward ratio.
     *      This function creates a new staking condition and increments the condition ID.
     *      It also manages the start and end timestamps for staking conditions.
     *      This function is meant to be called internally from setRewardRatio or setTimeUnit
     * @param _timeUnit The time unit for the new staking condition.
     * @param _numerator The numerator part of the reward ratio for the new staking condition.
     * @param _denominator The denominator part of the reward ratio for the new staking condition.
     */
    function _setStakingCondition(uint256 _timeUnit, uint256 _numerator, uint256 _denominator) internal virtual {
        require(_denominator != 0, "divide by 0");
        require(_numerator != 0, "numerator can't be 0");
        require(_numerator <= _denominator, "Reward ratio cannot be more than 100%");
        require(_timeUnit != 0, "time unit can't be 0");
        uint256 conditionId = nextConditionId;
        nextConditionId += 1;

        stakingConditions[conditionId] = StakingCondition({
            timeUnit: _timeUnit,
            rewardRatioNumerator: _numerator,
            rewardRatioDenominator: _denominator,
            startTimestamp: block.timestamp,
            endTimestamp: 0
        });

        if (conditionId > 0) {
            stakingConditions[conditionId - 1].endTimestamp = block.timestamp;
        }
    }

    /**
    * @notice Pauses all staking activities. Withdrawals are still authorized.
    * @dev Can only be called by the contract owner.
    * @dev Emits the Paused event (inherited from Pausable contract).
    */
    function pause() public onlyOwner {
        _pause();
    }

    /**
    * @notice Resumes all staking activities.
    * @dev Can only be called by the contract owner.
    * @dev Emits the Unpaused event (inherited from Pausable contract).
    */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
    * @notice Allows the owner to forcibly withdraw staked tokens from a staker's position in case of an emergency.
    * @dev This function can be called only by the owner.
    * @dev Emits the TokensWithdrawnAdmin event
    * @param _staker The address of the staker from whom tokens are being withdrawn.
    */
    function forceWithdraw(address _staker) public onlyOwner {
        uint256 _amountStaked = stakers[_staker].amountStaked;
        require(_amountStaked != 0, "Withdrawing 0 tokens");
        stakingTokenBalance -= _amountStaked;
        _updateUnclaimedRewardsForStaker(_staker);
        stakers[_staker].amountStaked -= _amountStaked;
        if (stakers[_staker].amountStaked == 0) {
            totalStakers --;
        }
        _safeTransferERC20(
            stakingToken,
            address(this),
            _staker,
            _amountStaked
        );
        emit TokensWithdrawnAdmin(_stakeMsgSender(), _amountStaked);
    }

    /**
    * @dev Internal function to handle the logic of staking tokens.
    *      Updates the staking balance and, if necessary, the unclaimed rewards for a staker.
    *      Emits a TokensStaked event upon successful staking.
    * @param _amount The amount of tokens to be staked.
    * @notice This function does not directly interact with users and is intended to be called by the stake function.
    */
    function _stake(uint256 _amount) internal virtual {
        require(_amount != 0, "Staking 0 tokens");
        address _stakingToken = stakingToken;

        if (stakers[_stakeMsgSender()].amountStaked > 0) {
            _updateUnclaimedRewardsForStaker(_stakeMsgSender());
        } else {
            stakers[_stakeMsgSender()].timeOfLastUpdate = block.timestamp;
            stakers[_stakeMsgSender()].conditionIdOflastUpdate = nextConditionId - 1;
            totalStakers++;
        }

        uint256 balanceBefore = IERC20(_stakingToken).balanceOf(address(this));
        _safeTransferERC20(
            stakingToken,
            _stakeMsgSender(),
            address(this),
            _amount
        );
        uint256 actualAmount = IERC20(_stakingToken).balanceOf(address(this)) - balanceBefore;

        stakers[_stakeMsgSender()].amountStaked += actualAmount;
        stakingTokenBalance += actualAmount;

        emit TokensStaked(_stakeMsgSender(), actualAmount);
    }

    /**
    * @dev Internal function to update the unclaimed rewards for a specific staking position.
    *      Calculates the new rewards based on the current staking condition and adds them
    *      to the staker's unclaimed rewards.
    * @param _staker The address of the staker whose rewards are being updated.
    */
    function _updateUnclaimedRewardsForStaker(address _staker) internal virtual {
        uint256 rewards = _calculateRewards(_staker);
        stakers[_staker].unclaimedRewards += rewards;
        stakers[_staker].timeOfLastUpdate = block.timestamp;
        stakers[_staker].conditionIdOflastUpdate = nextConditionId - 1;
    }

    /**
     * @dev Internal view function to calculate the rewards for a staker's position.
     *      The calculation takes into account the staker's amount staked, the time elapsed,
     *      the reward ratio of the current staking condition and the previous staking conditions if they applies.
     * @param _staker The address of the staker whose rewards are being calculated.
     * @return _rewards The total calculated reward amount for the staker.
     */
    function _calculateRewards(address _staker) internal view virtual returns (uint256 _rewards) {
        StakerStaking memory staker = stakers[_staker];

        uint256 _stakerConditionId = staker.conditionIdOflastUpdate;
        uint256 _nextConditionId = nextConditionId;

        for (uint256 i = _stakerConditionId; i < _nextConditionId; i += 1) {
            StakingCondition memory condition = stakingConditions[i];

            uint256 startTime = i != _stakerConditionId ? condition.startTimestamp : staker.timeOfLastUpdate;
            uint256 endTime = condition.endTimestamp != 0 ? condition.endTimestamp : block.timestamp;

            (bool noOverflowProduct, uint256 rewardsProduct) = Math.tryMul(
                (endTime - startTime) * staker.amountStaked,
                condition.rewardRatioNumerator
            );
            (bool noOverflowSum, uint256 rewardsSum) = Math.tryAdd(
                _rewards,
                (rewardsProduct / condition.timeUnit) / condition.rewardRatioDenominator
            );

            _rewards = noOverflowProduct && noOverflowSum ? rewardsSum : _rewards;
        }

        (, _rewards) = Math.tryMul(_rewards, 10 ** rewardTokenDecimals);

        _rewards /= (10 ** stakingTokenDecimals);
    }

    /// @dev Exposes the ability to override the msg sender -- support ERC2771.
    function _stakeMsgSender() internal virtual returns (address) {
        return msg.sender;
    }

    /**
    * @dev Internal function to safely transfer ERC20 tokens.
    *      It handles transfers between any two addresses, including the contract itself.
    * @param _currency The address of the ERC20 token to be transferred.
    * @param _from The address from which the tokens are transferred.
    * @param _to The address to which the tokens are transferred.
    * @param _amount The amount of tokens to be transferred.
    */
    function _safeTransferERC20(address _currency, address _from, address _to, uint256 _amount) internal {
        if (_from == _to) {
            return;
        }

        if (_from == address(this)) {
            SafeERC20.safeTransfer(IERC20(_currency), _to, _amount);
        } else {
            SafeERC20.safeTransferFrom(IERC20(_currency), _from, _to, _amount);
        }
    }

    /**
    * @dev Internal function to handle the logic of withdrawing staked tokens.
    *      This function updates the staker's balance, update the unclaimed rewards,
    *      and emits a TokensWithdrawn event upon successful withdrawal.
    * @param _amount The amount of tokens to be withdrawn.
    */
    function _withdraw(uint256 _amount) internal virtual {
        uint256 _amountStaked = stakers[_stakeMsgSender()].amountStaked;
        require(_amount != 0, "Withdrawing 0 tokens");
        require(_amountStaked >= _amount, "Withdrawing more than staked");

        _updateUnclaimedRewardsForStaker(_stakeMsgSender());

        stakers[_stakeMsgSender()].amountStaked -= _amount;
        stakingTokenBalance -= _amount;
        if (stakers[_stakeMsgSender()].amountStaked == 0) {
            totalStakers --;
        }

        _safeTransferERC20(
            stakingToken,
            address(this),
            _stakeMsgSender(),
            _amount
        );


        emit TokensWithdrawn(_stakeMsgSender(), _amount);
    }

    /**
    * @dev Internal function to handle the logic of claiming rewards for a staker.
    *      It calculates the total rewards, transfers them from the reward wallet to the staker,
    *      and updates relevant state variables.
    *      Emit the RewardsClaimed event
    */
    function _claimRewards() internal virtual {
        uint256 rewards = stakers[_stakeMsgSender()].unclaimedRewards + _calculateRewards(_stakeMsgSender());

        require(rewards != 0, "No rewards");

        stakers[_stakeMsgSender()].timeOfLastUpdate = block.timestamp;
        stakers[_stakeMsgSender()].unclaimedRewards = 0;
        stakers[_stakeMsgSender()].conditionIdOflastUpdate = nextConditionId - 1;
        stakersRewardClaimed[_stakeMsgSender()] += rewards;
        totalRewardClaimed += rewards;

        // @dev Transfer the reward to the user
        _safeTransferERC20(
            rewardToken,
            rewardWallet,
            _stakeMsgSender(),
            rewards
        );
        emit RewardsClaimed(_stakeMsgSender(), rewards);
    }

    /// @dev Return the information about a specific staker
    /// @param _staker Address of the staker.
    /// @return stackInfo The data for the staking position.
    function getStakingInfo(address _staker) external view returns (StakerStaking memory stackInfo) {
        require(stakers[_staker].timeOfLastUpdate > 0, "Staker not found");
        stackInfo = stakers[_staker];
        stackInfo.unclaimedRewards = stackInfo.unclaimedRewards + _calculateRewards(_staker);
    }

    /**
    * @notice Allows a user to stake a specified amount of tokens.
    *         This will create an new position for the user or increase an existing one.
    * @dev This function calls the internal _stake function and applies checks for pausing and reentrancy.
    * @param _amount The amount of tokens to be staked by the user.
    */
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        _stake(_amount);
    }

    /**
    * @notice Allows a user to withdraw tokens from their staking position.
    * @dev This function calls the internal _withdraw function for the specified amount.
    * @param amount The amount of tokens to withdraw..
    */
    function withdraw(uint256 amount) external nonReentrant {
        _withdraw(amount);
    }

    /**
    * @notice Allows a staker to claim their accumulated rewards.
    * @dev This function calls the internal _claimRewards function to handle the reward claiming logic.
    *      Emits a RewardsClaimed event upon successful claiming of rewards.
    */
    function claimRewards() external nonReentrant {
        _claimRewards();
    }
}