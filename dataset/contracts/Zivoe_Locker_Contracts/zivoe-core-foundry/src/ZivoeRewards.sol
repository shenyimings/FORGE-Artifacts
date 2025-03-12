// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./libraries/ZivoeVotes.sol";

import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

interface IZivoeGlobals_ZivoeRewards {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);

    /// @notice Returns true if an address is whitelisted as a depositor.
    function isDepositor(address) external view returns (bool);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount              The amount of a given "asset" to be standardized.
    /// @param  asset               The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount  The input amount, standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);
}



/// @notice This contract facilitates staking and yield distribution.
///         This contract has the following responsibilities:
///           - Allows staking and unstaking of modular "stakingToken".
///           - Allows claiming yield distributed / "deposited" to this contract.
///           - Allows multiple assets to be added as "rewardToken" for distributions.
///           - Vests rewardTokens linearly overtime to stakers.
contract ZivoeRewards is ReentrancyGuard, Context, ZivoeVotes {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    struct Reward {
        uint256 rewardsDuration;        /// @dev How long rewards take to vest, e.g. 30 days.
        uint256 periodFinish;           /// @dev When current rewards will finish vesting.
        uint256 rewardRate;             /// @dev Rewards emitted per second.
        uint256 lastUpdateTime;         /// @dev Last time this data struct was updated.
        uint256 rewardPerTokenStored;   /// @dev Last snapshot of rewardPerToken taken.
    }

    address public immutable GBL;       /// @dev The ZivoeGlobals contract.

    address[] public rewardTokens;      /// @dev Array of ERC20 tokens distributed as rewards (if present).

    uint256 private _totalSupply;       /// @dev Total supply of (non-transferrable) LP tokens for reards contract.

    /// @dev Contains rewards information for each rewardToken.
    mapping(address => Reward) public rewardData;

    /// @dev The order is account -> rewardAsset -> amount.
    mapping(address => mapping(address => uint256)) public accountRewardPerTokenPaid;

    /// @dev The order is account -> rewardAsset -> amount.
    mapping(address => mapping(address => uint256)) public rewards;

     /// @dev Contains LP token balance of each account (is 1:1 ratio with amount deposited).
    mapping(address => uint256) private _balances;

    IERC20 public stakingToken;         /// @dev IERC20 wrapper for the stakingToken (deposited to receive LP tokens).



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeRewards contract.
    /// @param _stakingToken The ERC20 asset deposited to mint LP tokens (and returned when burning LP tokens).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _stakingToken, address _GBL) {
        stakingToken = IERC20(_stakingToken);
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during addReward().
    /// @param  reward The asset that's being distributed.
    event RewardAdded(address indexed reward);

    /// @notice Emitted during depositReward().
    /// @param  reward The asset that's being deposited.
    /// @param  amount The amout deposited.
    /// @param  depositor The _msgSender() who deposited said reward.
    event RewardDeposited(address indexed reward, uint256 amount, address indexed depositor);

    /// @notice Emitted during _getRewardAt().
    /// @param  account The account receiving a reward.
    /// @param  rewardsToken The ERC20 asset distributed as a reward.
    /// @param  reward The amount of "rewardsToken" distributed.
    event RewardDistributed(address indexed account, address indexed rewardsToken, uint256 reward);

    /// @notice Emitted during stake().
    /// @param  account The account staking "stakingToken".
    /// @param  amount The amount of "stakingToken" staked.
    event Staked(address indexed account, uint256 amount);

    /// @notice Emitted during stakeFor().
    /// @param  account The account receiveing the staked position of "stakingToken".
    /// @param  amount The amount of "stakingToken" staked.
    /// @param  by The account facilitating the staking.
    event StakedFor(address indexed account, uint256 amount, address indexed by);

    /// @notice Emitted during withdraw().
    /// @param  account The account withdrawing "stakingToken".
    /// @param  amount The amount of "stakingToken" withdrawn.
    event Withdrawn(address indexed account, uint256 amount);



    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures account rewards information is updated BEFORE mutative actions.
    /// @param account The account to update personal rewards information if account != address(0).
    modifier updateReward(address account) {
        for (uint256 i; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = rewardPerToken(token);
            rewardData[token].lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                accountRewardPerTokenPaid[account][token] = rewardData[token].rewardPerTokenStored;
            }
        }
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Returns the amount of tokens owned by "account", received when depositing via stake().
    /// @param account The account to view information of.
    /// @return amount The amount of tokens owned by "account".
    function balanceOf(address account) external view returns (uint256 amount) { return _balances[account]; }
    
    /// @notice Returns the total amount of rewards being distributed to everyone for current rewardsDuration.
    /// @param  _rewardsToken The asset that's being distributed.
    /// @return amount The amount of rewards being distributed.
    function getRewardForDuration(address _rewardsToken) external view returns (uint256 amount) {
        return rewardData[_rewardsToken].rewardRate.mul(rewardData[_rewardsToken].rewardsDuration);
    }

    /// @notice Returns the amount of tokens in existence; these are minted and burned when depositing or withdrawing.
    /// @return amount The amount of tokens in existence.
    function totalSupply() external view returns (uint256 amount) { return _totalSupply; }

    /// @notice Returns the last snapshot of rewardPerTokenStored taken for a reward asset.
    /// @param account The account to view information of.
    /// @param rewardAsset The reward token for which we want to return the rewardPerTokenstored.
    /// @return amount The latest up-to-date value of rewardPerTokenStored.
    function viewAccountRewardPerTokenPaid(
        address account, address rewardAsset
    ) external view returns (uint256 amount) {
        return accountRewardPerTokenPaid[account][rewardAsset];
    }

    /// @notice Returns the rewards earned of a specific rewardToken for an address.
    /// @param account The account to view information of.
    /// @param rewardAsset The asset earned as a reward.
    /// @return amount The amount of rewards earned.
    function viewRewards(address account, address rewardAsset) external view returns (uint256 amount) {
        return rewards[account][rewardAsset];
    }

    /// @notice Provides information on the rewards available for claim.
    /// @param account The account to view information of.
    /// @param _rewardsToken The asset that's being distributed.
    /// @return amount The amount of rewards earned.
    function earned(address account, address _rewardsToken) public view returns (uint256 amount) {
        return _balances[account].mul(
            rewardPerToken(_rewardsToken).sub(accountRewardPerTokenPaid[account][_rewardsToken])
        ).div(1e18).add(rewards[account][_rewardsToken]);
    }

    /// @notice Helper function for assessing distribution timelines.
    /// @param _rewardsToken The asset that's being distributed.
    /// @return timestamp The most recent time (in UNIX format) at which rewards are available for distribution.
    function lastTimeRewardApplicable(address _rewardsToken) public view returns (uint256 timestamp) {
        return Math.min(block.timestamp, rewardData[_rewardsToken].periodFinish);
    }

    /// @notice Cumulative amount of rewards distributed per LP token.
    /// @param _rewardsToken The asset that's being distributed.
    /// @return amount The cumulative amount of rewards distributed per LP token.
    function rewardPerToken(address _rewardsToken) public view returns (uint256 amount) {
        if (_totalSupply == 0) { return rewardData[_rewardsToken].rewardPerTokenStored; }
        return rewardData[_rewardsToken].rewardPerTokenStored.add(
            lastTimeRewardApplicable(_rewardsToken).sub(
                rewardData[_rewardsToken].lastUpdateTime
            ).mul(rewardData[_rewardsToken].rewardRate).mul(1e18).div(_totalSupply)
        );
    }

    /// @notice Adds a new asset as a reward to this contract.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param _rewardsDuration How long rewards take to vest, e.g. 30 days (denoted in seconds).
    function addReward(address _rewardsToken, uint256 _rewardsDuration) external {
        require(
            _msgSender() == IZivoeGlobals_ZivoeRewards(GBL).ZVL(), 
            "_msgSender() != IZivoeGlobals_ZivoeRewards(GBL).ZVL()")
        ;
        require(_rewardsDuration > 0, "ZivoeRewards::addReward() _rewardsDuration == 0");
        require(
            rewardData[_rewardsToken].rewardsDuration == 0, 
            "ZivoeRewards::addReward() rewardData[_rewardsToken].rewardsDuration != 0"
        );
        require(rewardTokens.length < 10, "ZivoeRewards::addReward() rewardTokens.length >= 10");

        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardAdded(_rewardsToken);
    }

    /// @notice Deposits a reward to this contract for distribution.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param reward The amount of the _rewardsToken to deposit.
    function depositReward(address _rewardsToken, uint256 reward) external updateReward(address(0)) nonReentrant {
        require(
            IZivoeGlobals_ZivoeRewards(GBL).isDepositor(_msgSender()),
            "!IZivoeGlobals_ZivoeRewards(GBL).isDepositor(_msgSender())"
        );
        IERC20(_rewardsToken).safeTransferFrom(_msgSender(), address(this), reward);

        uint adjustedReward = IZivoeGlobals_ZivoeRewards(GBL).standardize(reward, _rewardsToken);

        // Update vesting accounting for reward (if existing rewards being distributed, increase proportionally).
        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = adjustedReward.div(rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = adjustedReward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardData[_rewardsToken].rewardsDuration);
        emit RewardDeposited(_rewardsToken, reward, _msgSender());
    }

    /// @notice Simultaneously calls withdraw() and getRewards() for convenience.
    function fullWithdraw() external {
        withdraw(_balances[_msgSender()]);
        getRewards();
    }

    /// @notice Stakes the specified amount of stakingToken to this contract.
    /// @param amount The amount of the _rewardsToken to deposit.
    function stake(uint256 amount) external nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::stake() amount == 0");

        _totalSupply = _totalSupply.add(amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
        _writeCheckpoint(_checkpoints[_msgSender()], _add, amount);
        _balances[_msgSender()] = _balances[_msgSender()].add(amount);
        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount);
    }

    /// @notice Stakes the specified amount of stakingToken to this contract, awarded to someone else.
    /// @dev    This takes stakingToken from _msgSender() and awards stake to "account".
    /// @param amount The amount of the _rewardsToken to deposit.
    /// @param account The account to stake for (that ultimately receives the stake).
    function stakeFor(uint256 amount, address account) external nonReentrant updateReward(account) {
        require(amount > 0, "ZivoeRewards::stakeFor() amount == 0");
        require(account != address(0), "ZivoeRewards::stakeFor() account == address(0)");

        _totalSupply = _totalSupply.add(amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _add, amount);
        _writeCheckpoint(_checkpoints[account], _add, amount);
        _balances[account] = _balances[account].add(amount);
        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit StakedFor(account, amount, _msgSender());
    }
    
    /// @notice Claim rewards for all possible _rewardTokens.
    function getRewards() public updateReward(_msgSender()) {
        for (uint256 i = 0; i < rewardTokens.length; i++) { _getRewardAt(i); }
    }
    
    /// @notice Claim rewards for a specific _rewardToken.
    /// @param index The index to claim, corresponds to a given index of rewardToken[].
    function _getRewardAt(uint256 index) internal nonReentrant {
        address _rewardsToken = rewardTokens[index];
        uint256 reward = rewards[_msgSender()][_rewardsToken];
        if (IERC20Metadata(_rewardsToken).decimals() < 18) { 
            reward /= 10 ** (18 - IERC20Metadata(_rewardsToken).decimals());
        }
        if (reward > 0) {
            rewards[_msgSender()][_rewardsToken] = 0;
            IERC20(_rewardsToken).safeTransfer(_msgSender(), reward);
            emit RewardDistributed(_msgSender(), _rewardsToken, reward);
        }
    }

    /// @notice Withdraws the specified amount of stakingToken from this contract.
    /// @param amount The amount of the _rewardsToken to withdraw.
    function withdraw(uint256 amount) public nonReentrant updateReward(_msgSender()) {
        require(amount > 0, "ZivoeRewards::withdraw() amount == 0");

        _totalSupply = _totalSupply.sub(amount);
        _writeCheckpoint(_totalSupplyCheckpoints, _subtract, amount);
        _writeCheckpoint(_checkpoints[_msgSender()], _subtract, amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        stakingToken.safeTransfer(_msgSender(), amount);
        emit Withdrawn(_msgSender(), amount);
    }

}
