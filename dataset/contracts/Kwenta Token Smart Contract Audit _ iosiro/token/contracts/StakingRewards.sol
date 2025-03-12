// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./utils/Owned.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/ISupplySchedule.sol";
import "./interfaces/IRewardEscrow.sol";

/// @title KWENTA Staking Rewards
/// @author SYNTHETIX, JaredBorders (jaredborders@proton.me), JChiaramonte7 (jeremy@bytecode.llc)
/// @notice Updated version of Synthetix's StakingRewards with new features specific
/// to Kwenta
contract StakingRewards is IStakingRewards, Owned, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /*///////////////////////////////////////////////////////////////
                                CONSTANTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice token used for BOTH staking and rewards
    IERC20 public immutable token;

    /// @notice escrow contract which holds (and may stake) reward tokens
    IRewardEscrow public immutable rewardEscrow;

    /// @notice handles reward token minting logic
    ISupplySchedule public immutable supplySchedule;

    /*///////////////////////////////////////////////////////////////
                                STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice number of tokens staked by address
    /// @dev this includes escrowed tokens stake
    mapping(address => uint256) private balances;

    /// @notice number of staked escrow tokens by address
    mapping(address => uint256) private escrowedBalances;

    /// @notice marks applicable reward period finish time
    uint256 public periodFinish = 0;

    /// @notice amount of tokens minted per second
    uint256 public rewardRate = 0;

    /// @notice period for rewards
    uint256 public rewardsDuration = 7 days;

    /// @notice track last time the rewards were updated
    uint256 public lastUpdateTime;

    /// @notice summation of rewardRate divided by total staked tokens
    uint256 public rewardPerTokenStored;

    /// @notice total number of tokens staked in this contract
    uint256 public _totalSupply;

    /// @notice represents the rewardPerToken
    /// value the last time the stake calculated earned() rewards
    mapping(address => uint256) public userRewardPerTokenPaid;

    /// @notice track rewards for a given user which changes when
    /// a user stakes, unstakes, or claims rewards
    mapping(address => uint256) public rewards;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice update reward rate
    /// @param reward: amount to be distributed over applicable rewards duration
    event RewardAdded(uint256 reward);

    /// @notice emitted when user stakes tokens
    /// @param user: staker address
    /// @param amount: amount staked
    event Staked(address indexed user, uint256 amount);

    /// @notice emitted when user unstakes tokens
    /// @param user: address of user unstaking
    /// @param amount: amount unstaked
    event Unstaked(address indexed user, uint256 amount);

    /// @notice emitted when escrow staked
    /// @param user: owner of escrowed tokens address
    /// @param amount: amount staked
    event EscrowStaked(address indexed user, uint256 amount);

    /// @notice emitted when staked escrow tokens are unstaked
    /// @param user: owner of escrowed tokens address
    /// @param amount: amount unstaked
    event EscrowUnstaked(address user, uint256 amount);

    /// @notice emitted when user claims rewards
    /// @param user: address of user claiming rewards
    /// @param reward: amount of reward token claimed
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice emitted when rewards duration changes
    /// @param newDuration: denoted in seconds
    event RewardsDurationUpdated(uint256 newDuration);

    /// @notice emitted when tokens are recovered from this contract
    /// @param token: address of token recovered
    /// @param amount: amount of token recovered
    event Recovered(address token, uint256 amount);

    /*///////////////////////////////////////////////////////////////
                                AUTH
    ///////////////////////////////////////////////////////////////*/

    /// @notice access control modifier for rewardEscrow
    modifier onlyRewardEscrow() {
        require(
            msg.sender == address(rewardEscrow),
            "StakingRewards: Only Reward Escrow"
        );
        _;
    }

    /// @notice access control modifier for rewardEscrow
    modifier onlySupplySchedule() {
        require(
            msg.sender == address(supplySchedule),
            "StakingRewards: Only Supply Schedule"
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /// @notice configure StakingRewards state
    /// @dev owner set to address that deployed StakingRewards
    /// @param _token: token used for staking and for rewards
    /// @param _rewardEscrow: escrow contract which holds (and may stake) reward tokens
    /// @param _supplySchedule: handles reward token minting logic
    constructor(
        address _token,
        address _rewardEscrow,
        address _supplySchedule
    ) Owned(msg.sender) {
        // define reward/staking token
        token = IERC20(_token);

        // define contracts which will interact with StakingRewards
        rewardEscrow = IRewardEscrow(_rewardEscrow);
        supplySchedule = ISupplySchedule(_supplySchedule);
    }

    /*///////////////////////////////////////////////////////////////
                                VIEWS
    ///////////////////////////////////////////////////////////////*/

    /// @dev returns staked tokens which will likely not be equal to total tokens
    /// in the contract since reward and staking tokens are the same
    /// @return total amount of tokens that are being staked
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /// @param account: address of potential staker
    /// @return amount of tokens staked by account
    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account];
    }

    /// @notice Getter function for number of staked escrow tokens
    /// @param account address to check the escrowed tokens staked
    /// @return amount of escrowed tokens staked
    function escrowedBalanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return escrowedBalances[account];
    }

    /// @return rewards for the duration specified by rewardsDuration
    function getRewardForDuration() external view override returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    /// @notice Getter function for number of staked non-escrow tokens
    /// @param account address to check the non-escrowed tokens staked
    /// @return amount of non-escrowed tokens staked
    function nonEscrowedBalanceOf(address account)
        public
        view
        override
        returns (uint256)
    {
        return balances[account] - escrowedBalances[account];
    }

    /*///////////////////////////////////////////////////////////////
                            STAKE/UNSTAKE
    ///////////////////////////////////////////////////////////////*/

    /// @notice stake token
    /// @param amount: amount to stake
    /// @dev updateReward() called prior to function logic
    function stake(uint256 amount)
        external
        override
        nonReentrant
        whenNotPaused
        updateReward(msg.sender)
    {
        require(amount > 0, "StakingRewards: Cannot stake 0");

        // update state
        _totalSupply += amount;
        balances[msg.sender] += amount;

        // transfer token to this contract from the caller
        token.safeTransferFrom(msg.sender, address(this), amount);

        // emit staking event and index msg.sender
        emit Staked(msg.sender, amount);
    }

    /// @notice unstake token
    /// @param amount: amount to unstake
    /// @dev updateReward() called prior to function logic
    function unstake(uint256 amount)
        public
        override
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "StakingRewards: Cannot Unstake 0");
        require(
            amount <= nonEscrowedBalanceOf(msg.sender),
            "StakingRewards: Invalid Amount"
        );

        // update state
        _totalSupply -= amount;
        balances[msg.sender] -= amount;

        // transfer token from this contract to the caller
        token.safeTransfer(msg.sender, amount);

        // emit unstake event and index msg.sender
        emit Unstaked(msg.sender, amount);
    }

    /// @notice stake escrowed token
    /// @param account: address which owns token
    /// @param amount: amount to stake
    /// @dev updateReward() called prior to function logic
    /// @dev msg.sender NOT used (account is used)
    function stakeEscrow(address account, uint256 amount)
        external
        override
        whenNotPaused
        onlyRewardEscrow
        updateReward(account)
    {
        require(amount > 0, "StakingRewards: Cannot stake 0");

        // update state
        balances[account] += amount;
        escrowedBalances[account] += amount;

        // updates total supply despite no new staking token being transfered.
        // escrowed tokens are locked in RewardEscrow
        _totalSupply += amount;

        // emit escrow staking event and index _account
        emit EscrowStaked(account, amount);
    }

    /// @notice unstake escrowed token
    /// @param account: address which owns token
    /// @param amount: amount to unstake
    /// @dev updateReward() called prior to function logic
    /// @dev msg.sender NOT used (account is used)
    function unstakeEscrow(address account, uint256 amount)
        external
        override
        nonReentrant
        onlyRewardEscrow
        updateReward(account)
    {
        require(amount > 0, "StakingRewards: Cannot Unstake 0");
        require(
            escrowedBalances[account] >= amount,
            "StakingRewards: Invalid Amount"
        );

        // update state
        balances[account] -= amount;
        escrowedBalances[account] -= amount;

        // updates total supply despite no new staking token being transfered.
        // escrowed tokens are locked in RewardEscrow
        _totalSupply -= amount;

        // emit escrow unstaked event and index account
        emit EscrowUnstaked(account, amount);
    }

    /// @notice unstake all available staked non-escrowed tokens and
    /// claim any rewards
    function exit() external override {
        unstake(nonEscrowedBalanceOf(msg.sender));
        getReward();
    }    

    /*///////////////////////////////////////////////////////////////
                            CLAIM REWARDS
    ///////////////////////////////////////////////////////////////*/

    /// @notice caller claims any rewards generated from staking
    /// @dev rewards are escrowed in RewardEscrow
    /// @dev updateReward() called prior to function logic
    function getReward() public override nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            // update state (first)
            rewards[msg.sender] = 0;

            // transfer token from this contract to the caller
            token.safeTransfer(address(rewardEscrow), reward);
            rewardEscrow.appendVestingEntry(msg.sender, reward, 52 weeks);

            // emit reward claimed event and index msg.sender
            emit RewardPaid(msg.sender, reward);
        }
    }

    /*///////////////////////////////////////////////////////////////
                        REWARD UPDATE CALCULATIONS
    ///////////////////////////////////////////////////////////////*/

    /// @notice update reward state for the account and contract
    /// @param account: address of account which rewards are being updated for
    /// @dev contract state not specific to an account will be updated also
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();

        if (account != address(0)) {
            // update amount of rewards a user can claim
            rewards[account] = earned(account);

            // update reward per token staked AT this given time
            // (i.e. when this user is interacting with StakingRewards)
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /// @notice calculate running sum of reward per total tokens staked
    /// at this specific time
    /// @return running sum of reward per total tokens staked
    function rewardPerToken() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) / (_totalSupply));
    }

    /// @return timestamp of the last time rewards are applicable
    function lastTimeRewardApplicable() public view override returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /// @notice determine how much reward token an account has earned thus far
    /// @param account: address of account earned amount is being calculated for
    function earned(address account) public view override returns (uint256) {
        return
            ((balances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    /*///////////////////////////////////////////////////////////////
                            SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /// @notice configure reward rate
    /// @param reward: amount of token to be distributed over a period
    /// @dev updateReward() called prior to function logic (with zero address)
    function notifyRewardAmount(uint256 reward)
        external
        override
        onlySupplySchedule
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    /// @notice set rewards duration
    /// @param _rewardsDuration: denoted in seconds
    function setRewardsDuration(uint256 _rewardsDuration)
        external
        override
        onlyOwner
    {
        require(
            block.timestamp > periodFinish,
            "StakingRewards: Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /*///////////////////////////////////////////////////////////////
                            PAUSABLE
    ///////////////////////////////////////////////////////////////*/

    /// @dev Triggers stopped state
    function pauseStakingRewards() external override onlyOwner {
        Pausable._pause();
    }

    /// @dev Returns to normal state.
    function unpauseStakingRewards() external override onlyOwner {
        Pausable._unpause();
    }

    /*///////////////////////////////////////////////////////////////
                            MISCELLANEOUS
    ///////////////////////////////////////////////////////////////*/

    /// @notice added to support recovering LP Rewards from other systems
    /// such as BAL to be distributed to holders
    /// @param tokenAddress: address of token to be recovered
    /// @param tokenAmount: amount of token to be recovered
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        override
        onlyOwner
    {
        require(
            tokenAddress != address(token),
            "StakingRewards: Cannot unstake the staking token"
        );
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
}
