// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IKrStaking {
    struct UserInfo {
        uint256 amount;
        uint256[] rewardDebts;
    }

    struct PoolInfo {
        IERC20 depositToken; // Address of LP token contract.
        uint128 allocPoint; // How many allocation points assigned to this pool.
        uint128 lastRewardBlock; // Last block number that rewards distribution occurs.
        uint256[] accRewardPerShares; // Accumulated rewards per share, times 1e12.
        address[] rewardTokens; // Reward tokens for this pool.
    }

    struct Reward {
        uint256 pid;
        address[] tokens;
        uint256[] amounts;
    }

    /**
     * @notice Get id for a token
     * @notice Useful for external contracts
     * @param _depositToken depositToken in `_poolInfo`
     * @return pid of pool with `_depositToken`
     * @return found ensure 0 index
     */
    function getPidFor(address _depositToken) external view returns (uint256 pid, bool found);

    /**
     * @notice Amount of pools
     */
    function poolLength() external view returns (uint256);

    /**
     * @notice Deposits tokens for @param _to
     * @param _to address that msg.sender deposits tokens for
     * @param _pid in `_poolInfo`
     * @param _amount amount of tokens to deposit
     */
    function deposit(address _to, uint256 _pid, uint256 _amount) external payable;

    /**
     * @notice Trusted helper contract can withdraw rewards and deposits on behalf of an account
     * @notice For eg. withdraw + remove liquidity
     * @param _for account to withdraw from
     * @param _pid id in `_poolInfo`
     * @param _amount amount to withdraw
     * @param _rewardRecipient reward recipient
     */
    function withdrawFor(address _for, uint256 _pid, uint256 _amount, address _rewardRecipient) external payable;

    /**
     * @notice Trusted helper contract can claim rewards on behalf of an account
     * @param _for account to claim for
     * @param _pid id in `_poolInfo`
     * @param _rewardRecipient address that receives rewards
     */
    function claimFor(address _for, uint256 _pid, address _rewardRecipient) external payable;

    /**
     * @notice Get all pending rewards for an account
     * @param _account to get rewards for
     * @return all pending rewards
     */
    function allPendingRewards(address _account) external view returns (Reward[] memory);

    /**
     * @notice Get account information on a pool
     * @param _pid in `_poolInfo`
     * @param _account to get information for
     * @return information on the account
     */
    function userInfo(uint256 _pid, address _account) external view returns (UserInfo memory);

    /**
     * @notice Get pool information
     * @param _pid in `_poolInfo`
     * @return pool information
     */
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);

    function rewardPerBlockFor(address depositTokenAddress) external view returns (uint256 rewardPerBlocks);

    /**
     * @notice A rescue function for missent msg.value
     * @notice Since we are using payable functions to save gas on calls
     */
    function rescueNative() external payable;

    /**
     * @notice A rescue function for missent tokens / airdrops
     * @notice This cannot withdraw any deposits due `ensurePoolDoesNotExist` modifier.
     */
    function rescueNonPoolToken(IERC20 _tokenToRescue, uint256 _amount) external payable;

    /**
     * @notice Set new allocations for a pool
     * @notice Set `_newAllocPoint` to 0 to retire a pool
     * @param _pid pool to modify
     * @param _newAllocPoint new allocation (weight) for rewards
     */
    function setPool(uint256 _pid, uint128 _newAllocPoint) external payable;

    /**
     * @notice Adds a new reward pool
     * @notice Updates reward token count in case of adding extra tokens
     * @param _rewardTokens tokens to reward from this pool
     * @param _depositToken token to deposit for rewards
     * @param _allocPoint weight of rewards this pool receives
     * @param _startBlock block when rewards start
     */
    function addPool(
        address[] calldata _rewardTokens,
        IERC20 _depositToken,
        uint128 _allocPoint,
        uint128 _startBlock
    ) external payable;

    /**
     * @notice Adjust/Set reward per block for a particular reward token
     * @param _rewardToken token to adjust the drip for
     * @param _rewardPerBlock tokens to drip per block
     */
    function setRewardPerBlockFor(address _rewardToken, uint256 _rewardPerBlock) external payable;

    /**
     * @notice Emergency function, withdraws deposits from a pool
     * @notice This will forfeit your rewards.
     * @param _pid pool id to withdraw tokens from
     */
    function emergencyWithdraw(uint256 _pid) external payable;

    /**
     * @notice Claim rewards only
     * @param _pid id in `_poolInfo`
     * @param _rewardRecipient address to send rewards to
     */
    function claim(uint256 _pid, address _rewardRecipient) external payable;

    /**
     * @notice Withdraw deposited tokens and rewards.
     * @param _pid id in `_poolInfo`
     * @param _amount amount to withdraw
     * @param _rewardRecipient address to send rewards to
     */
    function withdraw(uint256 _pid, uint256 _amount, address _rewardRecipient) external payable;

    /**
     * @notice Updates all pools to be up-to date
     */
    function massUpdatePools() external payable;

    /**
     * @notice Updates a pools reward variables to be up-to date
     * @param _pid pool to update
     */
    function updatePool(uint256 _pid) external payable returns (PoolInfo memory pool);

    /**
     * @notice Get pending rewards from a certain pool
     * @param _pid id in `_poolInfo`
     * @param _user id in `_userInfo[_pid]`
     * @return rewards pending rewards
     */
    function pendingRewards(uint256 _pid, address _user) external view returns (Reward memory rewards);
}
