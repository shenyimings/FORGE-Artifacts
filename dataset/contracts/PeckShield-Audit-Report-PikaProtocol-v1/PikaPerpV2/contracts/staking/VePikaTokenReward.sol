// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '../staking/PikaMine.sol';
import "../access/Governable.sol";

/** @title VePikaTokenReward
    @notice Contract to distribute token rewards for vePIKA holders. Adapted from: https://github.com/ribbon-finance/governance/blob/main/contracts/rbn-staking/VeRBNRewards.sol
 */

contract VePikaTokenReward is Governable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public rewardToken; // immutable are breaking coverage software should be added back after.
    IERC20 public veToken; // immutable
    PikaMine public pikaMine;
    uint256 public duration = 30 days;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public currentRewards = 0;
    uint256 public historicalRewards = 0;
    address public admin;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardDurationUpdated(uint256 newDuration);
    event RewardAdded(uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);
    event UpdatedAdmin(address admin);

    constructor(
        address veToken_,
        address rewardToken_,
        address pikaMine_
    ) {
        veToken = IERC20(veToken_);
        rewardToken = IERC20(rewardToken_);
        pikaMine = PikaMine(pikaMine_);
        admin = msg.sender;
    }

    modifier _updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = _earnedReward(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /**
     *  @return timestamp until rewards are distributed
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /** @notice reward per token deposited
     *  @dev gives the total amount of rewards distributed since inception of the pool per vault token
     *  @return rewardPerToken
     */
    function rewardPerToken() public view returns (uint256) {
        uint256 supply = veToken.totalSupply();
        if (supply == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored +
        (((lastTimeRewardApplicable() - lastUpdateTime) *
        rewardRate *
        1e18) / supply);
    }

    function _earnedReward(address account) internal view returns (uint256) {
        return (veToken.balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account];
    }

    /** @notice earning for an account
     *  @return amount of tokens earned
     */
    function earned(address account) external view returns (uint256) {
        return _earnedReward(account);
    }

    /** @notice use to update rewards on vePIKA balance changes.
        @dev called by vePIKA
     *  @return true
     */
    function updateReward(address _account)
    external
    _updateReward(_account)
    returns (bool)
    {
        require(msg.sender == address(pikaMine), "!authorized");

        return true;
    }

    /**
     * @notice
     *  Get rewards
     */
    function getReward() external nonReentrant {
        _getReward(msg.sender);
    }

    function _getReward(address _account)
    internal
    _updateReward(_account)
    {
        uint256 reward = rewards[_account];
        if (reward == 0) return;
        rewards[_account] = 0;
        SafeERC20.safeTransfer(rewardToken, _account, reward);

        emit RewardPaid(_account, reward);
    }

    /**
     * @notice
     * Add new rewards to be distributed over the duration
     * @dev Trigger rewardRate recalculation using _amount
     * @param _amount token to add to rewards
     * @return true
     */
    function queueNewRewards(uint256 _amount) external returns (bool) {
        require(msg.sender == admin, "!authorized");
        require(_amount != 0, "==0");
        IERC20(rewardToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        _notifyRewardAmount(_amount);
        return true;
    }

    function _notifyRewardAmount(uint256 reward)
    internal
    _updateReward(address(0))
    {
        historicalRewards = historicalRewards + reward;
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            reward = reward + leftover;
            rewardRate = reward / duration;
        }
        currentRewards = reward;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardAdded(reward);
    }

    function setDuration(uint256 _duration) external {
        require(msg.sender == admin, "!authorized");
        require(block.timestamp >= periodFinish, "Not finished yet");
        duration = _duration;
        emit RewardDurationUpdated(_duration);
    }

    function setAdmin(address _admin) external onlyGov returns (bool) {
        require(_admin != address(0), "0 address");
        admin = _admin;
        emit UpdatedAdmin(_admin);
        return true;
    }

    function sweep(address _token) external returns (bool) {
        require(msg.sender == admin, "!authorized");
        require(
            _token != address(rewardToken) || pikaMine.isUnlocked(),
            "!rewardToken"
        );

        SafeERC20.safeTransfer(
            IERC20(_token),
            admin,
            IERC20(_token).balanceOf(address(this))
        );
        return true;
    }
}