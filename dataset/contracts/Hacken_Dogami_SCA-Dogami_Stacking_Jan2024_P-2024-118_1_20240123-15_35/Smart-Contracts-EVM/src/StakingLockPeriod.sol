// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";

/// @title Lock Period Staking contract
contract StakingLockPeriod is Ownable, Pausable, ReentrancyGuard {

    /// @dev Emitted when tokens are staked.
    event TokensStaked(address indexed staker, uint256 amount);

    /// @dev Emitted when a tokens are withdrawn.
    event TokensWithdrawn(address indexed staker, uint256 amount);

    /// @dev Emergency event to force the withdrawals of funds
    event TokensWithdrawnAdmin(address indexed staker, uint256 amount);

    /// @dev Emitted when a staker claims their rewards
    event RewardsClaimed(address indexed staker, uint256 rewardAmount);

    /// @dev Represent the staking condition of the contract
    struct StakingCondition {
        uint80 timeUnit;
        uint256 rewardRatioNumerator;
        uint256 rewardRatioDenominator;
    }

    /// @dev Represent a staker position
    struct StakerStaking {
        uint256 timeOfLastUpdate;
        uint256 unlockTime;
        uint256 amountStaked;
        uint256 unclaimedRewards;
    }

    /// @dev Mapping staker address to StakerStaking
    mapping(address => StakerStaking[]) public stakers;

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

    /// @dev Address of the wallet holdings the token rewards
    address public immutable rewardWallet;

    /// @dev Count the total number of unique stakers
    uint256 public totalStakers;

    /// @dev Count the total rewards claimed by all the users.
    uint256 public totalRewardClaimed;

    /// @dev Stacking condition
    StakingCondition public stakingCondition;

    /// @dev Time in second that token must be locked to collect the rewards
    uint256 public immutable lockPeriodDuration;

    /**
    * @notice Initializes a new StakingLockPeriod contract with specified token addresses, staking conditions, and reward wallet.
    * @dev Sets up the staking token, reward token, and initial staking conditions.
    *      It also sets the contract deployer as the owner.
    * @param _stakingToken Address of the ERC20 token used for staking.
    * @param _rewardToken Address of the ERC20 token used for rewards.
    * @param _rewardWallet Address of the wallet holding the reward tokens.
    * @param _timeUnit The time unit for calculating rewards.
    * @param _numerator The numerator part of the reward ratio.
    * @param _denominator The denominator part of the reward ratio, ensuring no division by zero.
    * @param _lockPeriodDuration The duration for which tokens must be locked to be eligible for rewards.
    */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _rewardWallet,
        uint80 _timeUnit,
        uint256 _numerator,
        uint256 _denominator,
        uint256 _lockPeriodDuration

    ) Ownable(msg.sender) {
        require(_denominator != 0, "Denominator cannot be zero");
        require(_numerator != 0, "Numerator cannot be zero");
        require(_timeUnit != 0, "Time unit cannot be zero");
        require(_lockPeriodDuration != 0, "Lock period cannot be zero");
        require(_numerator <= _denominator, "Reward ratio cannot be more than 100%");
        require(_rewardWallet != address(this), "Reward wallet cannot be the contract itself");
        require(_stakingToken != address(0) && _rewardToken != address(0) && _rewardWallet != address(0),
            "Staking/Reward token/wallet cannot be the zero address");
        stakingToken = _stakingToken;
        stakingTokenDecimals = IERC20Metadata(_stakingToken).decimals();
        rewardTokenDecimals = IERC20Metadata(_rewardToken).decimals();
        rewardToken = _rewardToken;
        rewardWallet = _rewardWallet;
        lockPeriodDuration = _lockPeriodDuration;
        stakingCondition = StakingCondition({
            timeUnit: _timeUnit,
            rewardRatioNumerator: _numerator,
            rewardRatioDenominator: _denominator
        });
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
    * @notice Allows the owner to forcibly withdraw staked tokens from a specified staker's position in case of an emergency.
    * @dev This function can be called only by the owner and does not distribute rewards.
    * @dev Emits the TokensWithdrawnAdmin event
    * @param _staker The address of the staker from whom tokens are being withdrawn.
    * @param stakeIndex The index of the staking position in the staker's array.
    */
    function forceWithdraw(address _staker, uint256 stakeIndex) public onlyOwner {
        require(stakers[_staker].length > 0, "Staker not found");
        require(stakeIndex < stakers[_staker].length, "Stacking not found");
        uint256 _amountStaked = stakers[_staker][stakeIndex].amountStaked;
        stakingTokenBalance -= _amountStaked;
        _removeStackingFromArray(_staker, stakeIndex);
        if (stakers[_staker].length == 0) {
            totalStakers --;
        }
        _safeTransferERC20(
            stakingToken,
            address(this),
            _staker,
            _amountStaked
        );
        emit TokensWithdrawnAdmin(_staker, _amountStaked);
    }

    /**
    * @dev Internal function to handle the logic of staking tokens.
    *      Updates the staking balance for a staker.
    *      Emits a TokensStaked event upon successful staking.
    * @param _amount The amount of tokens to be staked.
    * @notice This function does not directly interact with users and is intended to be called by the stake function.
    */
    function _stake(uint256 _amount) internal virtual {
        require(_amount != 0, "Staking 0 tokens");

        address _stakingToken = stakingToken;

        uint256 balanceBefore = IERC20(_stakingToken).balanceOf(address(this));
        _safeTransferERC20(
            stakingToken,
            _stakeMsgSender(),
            address(this),
            _amount
        );
        uint256 actualAmount = IERC20(_stakingToken).balanceOf(address(this)) - balanceBefore;
        StakerStaking memory newStakerStaking = StakerStaking({
            timeOfLastUpdate: block.timestamp,
            unlockTime: block.timestamp + lockPeriodDuration,
            amountStaked: actualAmount,
            unclaimedRewards: 0
        });

        if (stakers[_stakeMsgSender()].length == 0) {
            totalStakers ++;
        }
        stakers[_stakeMsgSender()].push(newStakerStaking);

        stakingTokenBalance += actualAmount;
        emit TokensStaked(_stakeMsgSender(), actualAmount);
    }

    /**
    * @dev Internal function to update the unclaimed rewards for a specific staking position.
    *      Calculates the new rewards based on the staking condition and adds them
    *      to the staker's unclaimed rewards.
    * @param _staker The address of the staker whose rewards are being updated.
    * @param stakeIndex The index of the staking position within the staker's array.
    */
    function _updateUnclaimedRewardsForStaker(address _staker, uint256 stakeIndex) internal virtual {
        uint256 rewards = _calculateRewards(_staker, stakeIndex);
        stakers[_staker][stakeIndex].unclaimedRewards += rewards;
        stakers[_staker][stakeIndex].timeOfLastUpdate = block.timestamp;
    }

    /**
    * @dev Internal view function to calculate the rewards for a given staker's staking position.
    *      The calculation is based on the staking amount and the reward ratio.
    * @param _staker The address of the staker whose rewards are being calculated.
    * @param stakeIndex The index of the staking position within the staker's array.
    * @return _rewards The calculated reward amount for the specified staking position.
    */
    function _calculateRewards(address _staker, uint256 stakeIndex) internal view virtual returns (uint256 _rewards) {
        StakerStaking memory staker = stakers[_staker][stakeIndex];

        StakingCondition memory condition = stakingCondition;
        uint256 startTime = staker.timeOfLastUpdate;
        // @dev Only calculate the reward at the end of the lock period.
        uint256 endTime = staker.unlockTime;

        (bool noOverflowProduct, uint256 rewardsProduct) = Math.tryMul(
            (endTime - startTime) * staker.amountStaked,
            condition.rewardRatioNumerator
        );
        (bool noOverflowSum, uint256 rewardsSum) = Math.tryAdd(
            _rewards,
            (rewardsProduct / condition.timeUnit) / condition.rewardRatioDenominator
        );

        _rewards = noOverflowProduct && noOverflowSum ? rewardsSum : _rewards;

        (, _rewards) = Math.tryMul(_rewards, 10 ** rewardTokenDecimals);

        _rewards /= (10 ** stakingTokenDecimals);
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
    *      It updates the staking balance, calculates and claims rewards if applicable,
    *      and emits a TokensWithdrawn event.
    * @param _amount The amount of tokens to be withdrawn.
    * @param stakeIndex The index of the staking position in the staker's array.
    */
    function _withdraw(uint256 _amount, uint256 stakeIndex) internal virtual {
        _updateUnclaimedRewardsForStaker(_stakeMsgSender(), stakeIndex);

        stakers[_stakeMsgSender()][stakeIndex].amountStaked -= _amount;

        stakingTokenBalance -= _amount;
        if (block.timestamp >= stakers[_stakeMsgSender()][stakeIndex].unlockTime) {
            _claimRewards(_stakeMsgSender(), stakeIndex);
        }
        _removeStackingFromArray(_stakeMsgSender(), stakeIndex);
        if (stakers[_stakeMsgSender()].length == 0) {
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
    * @dev Internal function to remove a staking instance from a staker's array.
    *      This is used when a staker withdraw their stake.
    * @param _stacker The address of the staker whose staking position is being removed.
    * @param stakeIndex The index of the staking position within the staker's array to be removed.
    */
    function _removeStackingFromArray(address _stacker, uint256 stakeIndex) internal {
        uint256 lastIndex = stakers[_stacker].length - 1;
        if (stakeIndex < lastIndex) {
            stakers[_stacker][stakeIndex] = stakers[_stacker][lastIndex];
        }
        stakers[_stacker].pop();
    }

    /**
    * @dev Internal function to handle the logic of claiming rewards for a staking position.
    *      It calculates the total rewards, transfers them from the reward wallet to the staker,
    *      and updates relevant state variables. This is used when a staker withdraws their stake.
    *      Emit the RewardsClaimed event.
    * @param _stacker The address of the staker who is claiming rewards.
    * @param stakeIndex The index of the staking position for which rewards are being claimed.
    */
    function _claimRewards(address _stacker, uint256 stakeIndex) internal {
        StakerStaking storage stackingInstance = stakers[_stacker][stakeIndex];

        uint256 rewards = stackingInstance.unclaimedRewards;

        stakers[_stacker][stakeIndex].timeOfLastUpdate = block.timestamp;
        stakers[_stacker][stakeIndex].unclaimedRewards = 0;
        stakersRewardClaimed[_stacker] += rewards;
        totalRewardClaimed += rewards;

        // @dev Transfer the reward to the user
        _safeTransferERC20(
            rewardToken,
            rewardWallet,
            _stacker,
            rewards
        );
        emit RewardsClaimed(_stacker, rewards);
    }

    /// @dev Exposes the ability to override the msg sender -- support ERC2771.
    function _stakeMsgSender() internal virtual returns (address) {
        return msg.sender;
    }

    /// @dev Return the number of stacking instances for a given wallet address.
    /// @param _staker Address of the staker.
    /// @return count The number of stacking instances for the staker.
    function getStackingCount(address _staker) external view returns (uint256 count) {
        count = stakers[_staker].length;
    }

    /// @dev Return the information about a specific staker position referenced by the stakeIndex
    /// @param _staker Address of the staker.
    /// @param stakeIndex Index of the staking position for the user.
    /// @return stackInfo The data for the staking position.
    function getStackingInfo(address _staker, uint256 stakeIndex) external view returns (StakerStaking memory stackInfo) {
        require(stakers[_staker].length > 0, "Staker not found");
        require(stakeIndex < stakers[_staker].length, "Stacking not found");

        stackInfo = stakers[_staker][stakeIndex];
        stackInfo.unclaimedRewards = _calculateRewards(_staker, stakeIndex);
    }

    /**
    * @notice Allows a user to stake a specified amount of tokens.
    * @dev This function calls the internal _stake for the specified amount.
    * @param _amount The amount of tokens to be staked by the user.
    */
    function stake(uint256 _amount) external whenNotPaused nonReentrant {
        _stake(_amount);
    }

    /**
    * @notice Allows a user to withdraw their entire stake from a specified staking position.
    * @dev This function calls the internal _withdraw function for the total staked amount.
    * @param stakeIndex The index of the staking position in the user's array of staked tokens.
    */
    function withdrawTotal(uint256 stakeIndex) external nonReentrant {
        require(stakers[_stakeMsgSender()].length > 0, "Staker not found");
        require(stakeIndex < stakers[_stakeMsgSender()].length, "Stacking not found");
        uint256 _amountStaked = stakers[_stakeMsgSender()][stakeIndex].amountStaked;
        _withdraw(_amountStaked, stakeIndex);
    }

}