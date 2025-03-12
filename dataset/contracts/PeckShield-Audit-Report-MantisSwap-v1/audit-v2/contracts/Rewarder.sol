// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * This is a sample contract to be used in the MasterMantis contract for partners to reward
 * stakers with their native token alongside MNT.
 *
 * It assumes no minting rights, so requires a set amount of YOUR_TOKEN to be transferred to this contract prior.
 * E.g. say you've allocated 100,000 XYZ to the MNT-XYZ farm over 30 days. Then you would need to transfer
 * 100,000 XYZ and set the block reward accordingly so it's fully distributed after 30 days.
 *
 */
contract Rewarder is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    IERC20 public immutable lpToken;
    address public immutable masterMantis;

    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of YOUR_TOKEN entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each poolInfo.
    /// `accTokenPerShare` Amount of YOUR_TOKEN each LP token is worth.
    /// `lastRewardBlock` The last block YOUR_TOKEN was rewarded to the poolInfo.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardBlock;
    }

    /// @notice Info of the poolInfo.
    PoolInfo public poolInfo;
    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public tokenPerBlock;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event OnReward(address indexed user, uint256 amount);
    event OnEmergencyWithdraw(address indexed user);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    modifier onlyMasterMantis() {
        require(msg.sender == masterMantis, "onlyMasterMantis: only MasterMantis can call this function");
        _;
    }

    constructor(IERC20 _rewardToken, IERC20 _lpToken, uint256 _tokenPerBlock, address _masterMantis) {
        require(Address.isContract(address(_rewardToken)), "constructor: reward token must be a valid contract");
        require(Address.isContract(address(_lpToken)), "constructor: LP token must be a valid contract");
        require(Address.isContract(_masterMantis), "constructor: MasterMantis must be a valid contract");

        rewardToken = _rewardToken;
        lpToken = _lpToken;
        tokenPerBlock = _tokenPerBlock;
        masterMantis = _masterMantis;
        poolInfo = PoolInfo({lastRewardBlock: block.number, accTokenPerShare: 0});
    }

    /// @notice Update reward variables of the given poolInfo.
    /// @return pool Returns the pool that was updated.
    function updatePool() public returns (PoolInfo memory pool) {
        pool = poolInfo;

        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = lpToken.balanceOf(masterMantis);

            if (lpSupply > 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 tokenReward = blocks * tokenPerBlock;
                pool.accTokenPerShare = pool.accTokenPerShare + (tokenReward * ACC_TOKEN_PRECISION / lpSupply);
            }

            pool.lastRewardBlock = block.number;
            poolInfo = pool;
        }
    }

    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerBlock The number of tokens to distribute per block
    function setRewardRate(uint256 _tokenPerBlock) external onlyOwner {
        updatePool();
        emit RewardRateUpdated(tokenPerBlock, _tokenPerBlock);
        tokenPerBlock = _tokenPerBlock;
    }

    /// @notice Function called by MasterMantis whenever staker claims JOE harvest. Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _lpAmount Number of LP tokens the user has
    function onMntReward(address _user, uint256 _lpAmount) external onlyMasterMantis {
        updatePool();
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 pending;
        // if user had deposited
        if (user.amount > 0) {
            pending = (user.amount * pool.accTokenPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
            uint256 balance = rewardToken.balanceOf(address(this));
            if (pending > balance) {
                rewardToken.safeTransfer(_user, balance);
            } else {
                rewardToken.safeTransfer(_user, pending);
            }
        }

        user.amount = _lpAmount;
        user.rewardDebt = user.amount * pool.accTokenPerShare / ACC_TOKEN_PRECISION;

        emit OnReward(_user, pending);
    }

    function onEmergencyWithdraw(address _user) external onlyMasterMantis {
        UserInfo storage user = userInfo[_user];
        user.amount = 0;
        user.rewardDebt = 0;
        emit OnEmergencyWithdraw(_user);
    }

    /// @notice View function to see pending tokens
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingTokens(address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo;
        UserInfo memory user = userInfo[_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = lpToken.balanceOf(masterMantis);

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 tokenReward = blocks * tokenPerBlock;
            accTokenPerShare += tokenReward * ACC_TOKEN_PRECISION / lpSupply;
        }

        pending = (user.amount * accTokenPerShare / ACC_TOKEN_PRECISION) - user.rewardDebt;
    }

    /// @notice In case rewarder is stopped before emissions finished, this function allows
    /// withdrawal of remaining tokens.
    function emergencyWithdraw() public onlyOwner {
        rewardToken.safeTransfer(address(msg.sender), rewardToken.balanceOf(address(this)));
    }
}