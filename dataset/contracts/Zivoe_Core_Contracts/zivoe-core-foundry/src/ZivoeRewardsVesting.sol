// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

interface IZivoeGlobals_ZivoeRewardsVesting {
    /// @notice Returns the address of the ZivoeITO contract.
    function ITO() external view returns (address);

    /// @notice Returns the address of the ZivoeToken contract.
    function ZVE() external view returns (address);

    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}

interface IZivoeITO_ZivoeRewardsVesting {
    /// @dev Tracks $pZVE (credits) an individual has from juniorDeposit().
    function juniorCredits(address) external returns(uint256);

    /// @dev Tracks $pZVE (credits) an individual has from seniorDeposit().
    function seniorCredits(address) external returns(uint256);
}



/// @notice  This contract facilitates staking and yield distribution, as well as vesting tokens.
///          This contract has the following responsibilities:
///            - Allows creation of vesting schedules (and revocation) for "vestingToken".
///            - Allows unstaking of vested tokens.
///            - Allows claiming yield distributed / "deposited" to this contract.
///            - Allows multiple assets to be added as "rewardToken" for distributions (except for "vestingToken").
///            - Vests rewardTokens linearly overtime to stakers.
contract ZivoeRewardsVesting is ReentrancyGuard, Context {

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

    struct VestingSchedule {
        uint256 start;              /// @dev The block.timestamp at which tokens will start vesting.
        uint256 cliff;              /// @dev The block.timestamp at which tokens are first claimable.
        uint256 end;         /// @dev The block.timestamp at which tokens will stop vesting (finished).
        uint256 totalVesting;       /// @dev The total amount to vest.
        uint256 totalWithdrawn;     /// @dev The total amount withdrawn so far.
        uint256 vestingPerSecond;   /// @dev The amount of vestingToken that vests per second.
        bool revokable;             /// @dev Whether or not this vesting schedule can be revoked.
    }
    
    address public immutable GBL;       /// @dev The ZivoeGlobals contract.

    address public vestingToken;        /// @dev The token vesting, in this case Zivoe ($ZVE).

    address[] public rewardTokens;      /// @dev Array of ERC20 tokens distributed as rewards (if present).
    
    uint256 public vestingTokenAllocated;   /// @dev The amount of vestingToken currently allocated.

    uint256 private _totalSupply;       /// @dev Total supply of (non-transferrable) LP tokens for reards contract.

    /// @dev Contains rewards information for each rewardToken.
    mapping(address => Reward) public rewardData;

    /// @dev Tracks if a wallet has been assigned a schedule.
    mapping(address => bool) public vestingScheduleSet;

    /// @dev Tracks the vesting schedule of accounts.
    mapping(address => VestingSchedule) public vestingScheduleOf;

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

    /// @notice Initializes the ZivoeRewardsVesting contract.
    /// @param _stakingToken The ERC20 asset deposited to mint LP tokens (and returned when burning LP tokens).
    /// @param _GBL The ZivoeGlobals contract.
    constructor(address _stakingToken, address _GBL) {
        stakingToken = IERC20(_stakingToken);
        vestingToken = _stakingToken;
        GBL = _GBL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during addReward().
    /// @param  reward The asset now supported as a reward.
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
    /// @param  amount The amount of  "stakingToken" staked.
    event Staked(address indexed account, uint256 amount);

    /// @notice Emitted during createVestingSchedule().
    /// @param  account The account that was given a vesting schedule.
    /// @return start The block.timestamp at which tokens will start vesting.
    /// @return cliff The block.timestamp at which tokens are first claimable.
    /// @return end The block.timestamp at which tokens will stop vesting (finished).
    /// @return totalVesting The total amount to vest.
    /// @return vestingPerSecond The amount of vestingToken that vests per second.
    /// @return revokable Whether or not this vesting schedule can be revoked.
    event VestingScheduleCreated(
        address indexed account, 
        uint256 start, 
        uint256 cliff, 
        uint256 end, 
        uint256 totalVesting, 
        uint256 vestingPerSecond, 
        bool revokable
    );

    /// @notice Emitted during revokeVestingSchedule().
    /// @param  account The account that was revoked a vesting schedule.
    /// @param  amountRevoked The amount of tokens revoked.
    /// @return cliff The updated value for cliff.
    /// @return end The updated value for end.
    /// @return totalVesting The total amount vested (claimable).
    /// @return revokable The final revokable status of schedule (always false after revocation).
    event VestingScheduleRevoked(
        address indexed account, 
        uint256 amountRevoked, 
        uint256 cliff, 
        uint256 end, 
        uint256 totalVesting, 
        bool revokable
    );

    /// @notice Emitted during withdraw().
    /// @param  account The account withdrawing "stakingToken".
    /// @param  amount The amount of "stakingToken" withdrawn.
    event Withdrawn(address indexed account, uint256 amount);



    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures the caller of a function is ZVL or ZivoeITO.
    modifier onlyZVLOrITO() {
        require(
            _msgSender() == IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVL() || 
            _msgSender() == IZivoeGlobals_ZivoeRewardsVesting(GBL).ITO(),
            "ZivoeRewardsVesting::onlyZVLOrITO() _msgSender() != ZVL && _msgSender() != ITO"
        );
        _;
    }

    /// @notice This modifier ensures account rewards information is updated BEFORE mutative actions.
    /// @param account The account to update personal rewards information of (if not address(0)).
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
    
    /// @notice Provides information for a vesting schedule.
    /// @param  account The account to view information of.
    /// @return start The block.timestamp at which tokens will start vesting.
    /// @return cliff The block.timestamp at which tokens are first claimable.
    /// @return end The block.timestamp at which tokens will stop vesting (finished).
    /// @return totalVesting The total amount to vest.
    /// @return totalWithdrawn The total amount withdrawn so far.
    /// @return vestingPerSecond The amount of vestingToken that vests per second.
    /// @return revokable Whether or not this vesting schedule can be revoked.
    function viewSchedule(address account) external view returns (
        uint256 start, 
        uint256 cliff, 
        uint256 end, 
        uint256 totalVesting, 
        uint256 totalWithdrawn, 
        uint256 vestingPerSecond, 
        bool revokable
    ) {
        start = vestingScheduleOf[account].start;
        cliff = vestingScheduleOf[account].cliff;
        end = vestingScheduleOf[account].end;
        totalVesting = vestingScheduleOf[account].totalVesting;
        totalWithdrawn = vestingScheduleOf[account].totalWithdrawn;
        vestingPerSecond = vestingScheduleOf[account].vestingPerSecond;
        revokable = vestingScheduleOf[account].revokable;
    }

    /// @notice Returns the amount of $ZVE tokens an account can withdraw.
    /// @param  account The account to be withdrawn from.
    /// @return amount Withdrawable amount of $ZVE tokens.
    function amountWithdrawable(address account) public view returns (uint256 amount) {
        if (block.timestamp < vestingScheduleOf[account].cliff) { return 0; }
        if (
            block.timestamp >= vestingScheduleOf[account].cliff && 
            block.timestamp < vestingScheduleOf[account].end
        ) {
            return vestingScheduleOf[account].vestingPerSecond * (
                block.timestamp - vestingScheduleOf[account].start
            ) - vestingScheduleOf[account].totalWithdrawn;
        }
        else if (block.timestamp >= vestingScheduleOf[account].end) {
            return vestingScheduleOf[account].totalVesting - vestingScheduleOf[account].totalWithdrawn;
        }
        else { return 0; }
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
            _msgSender() == IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVL(),
             "_msgSender() != IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVL()"
        );
        require(
            _rewardsToken != IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVE(), 
            "ZivoeRewardsVesting::addReward() _rewardsToken == IZivoeGlobals_ZivoeRewardsVesting(GBL).ZVE()"
        );
        require(_rewardsDuration > 0, "ZivoeRewardsVesting::addReward() _rewardsDuration == 0");
        require(
            rewardData[_rewardsToken].rewardsDuration == 0, 
            "ZivoeRewardsVesting::addReward() rewardData[_rewardsToken].rewardsDuration != 0"
        );
        require(rewardTokens.length < 10, "ZivoeRewardsVesting::addReward() rewardTokens.length >= 10");

        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].rewardsDuration = _rewardsDuration;
        emit RewardAdded(_rewardsToken);
    }

    /// @notice Deposits a reward to this contract for distribution.
    /// @param _rewardsToken The asset that's being distributed.
    /// @param reward The amount of the _rewardsToken to deposit.
    function depositReward(address _rewardsToken, uint256 reward) external updateReward(address(0)) nonReentrant {
        IERC20(_rewardsToken).safeTransferFrom(_msgSender(), address(this), reward);

        // Update vesting accounting for reward (if existing rewards being distributed, increase proportionally).
        if (block.timestamp >= rewardData[_rewardsToken].periodFinish) {
            rewardData[_rewardsToken].rewardRate = reward.div(rewardData[_rewardsToken].rewardsDuration);
        } else {
            uint256 remaining = rewardData[_rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardData[_rewardsToken].rewardRate);
            rewardData[_rewardsToken].rewardRate = reward.add(leftover).div(rewardData[_rewardsToken].rewardsDuration);
        }

        rewardData[_rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardsToken].periodFinish = block.timestamp.add(rewardData[_rewardsToken].rewardsDuration);
        emit RewardDeposited(_rewardsToken, reward, _msgSender());
    }

    /// @notice Simultaneously calls withdraw() and getRewards() for convenience.
    function fullWithdraw() external {
        withdraw();
        getRewards();
    }

    /// @notice Sets the vestingSchedule for an account.
    /// @param  account The account vesting $ZVE.
    /// @param  daysToCliff The number of days before vesting is claimable (a.k.a. cliff period).
    /// @param  daysToVest The number of days for the entire vesting period, from beginning to end.
    /// @param  amountToVest The amount of tokens being vested.
    /// @param  revokable If the vested amount can be revoked.
    function createVestingSchedule(
        address account, 
        uint256 daysToCliff, 
        uint256 daysToVest, 
        uint256 amountToVest, 
        bool revokable
    ) external onlyZVLOrITO {
        require(
            !vestingScheduleSet[account], 
            "ZivoeRewardsVesting::createVestingSchedule() vestingScheduleSet[account]"
        );
        require(
            IERC20(vestingToken).balanceOf(address(this)) - vestingTokenAllocated >= amountToVest, 
            "ZivoeRewardsVesting::createVestingSchedule() amountToVest > vestingToken.balanceOf(address(this)) - vestingTokenAllocated"
        );
        require(daysToVest <= 1800 days, "ZivoeRewardsVesting::createVestingSchedule() daysToVest > 1800 days");
        require(daysToCliff <= daysToVest, "ZivoeRewardsVesting::createVestingSchedule() daysToCliff > daysToVest");
        require(
            IZivoeITO_ZivoeRewardsVesting(IZivoeGlobals_ZivoeRewardsVesting(GBL).ITO()).seniorCredits(account) == 0 &&
            IZivoeITO_ZivoeRewardsVesting(IZivoeGlobals_ZivoeRewardsVesting(GBL).ITO()).juniorCredits(account) == 0,
            "ZivoeRewardsVesting::createVestingSchedule() seniorCredits(_msgSender) > 0 || juniorCredits(_msgSender) > 0"
        );

        vestingScheduleSet[account] = true;
        vestingTokenAllocated += amountToVest;
        
        vestingScheduleOf[account].start = block.timestamp;
        vestingScheduleOf[account].cliff = block.timestamp + daysToCliff * 1 days;
        vestingScheduleOf[account].end = block.timestamp + daysToVest * 1 days;
        vestingScheduleOf[account].totalVesting = amountToVest;
        vestingScheduleOf[account].vestingPerSecond = amountToVest / (daysToVest * 1 days);
        vestingScheduleOf[account].revokable = revokable;
        
        emit VestingScheduleCreated(
            account, 
            vestingScheduleOf[account].start, 
            vestingScheduleOf[account].cliff, 
            vestingScheduleOf[account].end, 
            vestingScheduleOf[account].totalVesting, 
            vestingScheduleOf[account].vestingPerSecond, 
            vestingScheduleOf[account].revokable
        );

        _stake(amountToVest, account);
    }

    /// NOTE: Conduct further fuzz testing in addition to unit testing here.
    /// @notice Ends vesting schedule for a given account (if revokable).
    /// @param  account The acount to revoke a vesting schedule for.
    function revokeVestingSchedule(address account) external updateReward(account) onlyZVLOrITO nonReentrant {
        require(
            vestingScheduleSet[account], 
            "ZivoeRewardsVesting::revokeVestingSchedule() !vestingScheduleSet[account]"
        );
        require(
            vestingScheduleOf[account].revokable, 
            "ZivoeRewardsVesting::revokeVestingSchedule() !vestingScheduleOf[account].revokable"
        );
        
        uint256 amount = amountWithdrawable(account);
        uint256 vestingAmount = vestingScheduleOf[account].totalVesting;

        vestingTokenAllocated -= amount;

        vestingScheduleOf[account].totalWithdrawn += amount;
        vestingScheduleOf[account].totalVesting = vestingScheduleOf[account].totalWithdrawn;
        vestingScheduleOf[account].cliff = block.timestamp - 1;
        vestingScheduleOf[account].end = block.timestamp;

        vestingTokenAllocated -= (vestingAmount - vestingScheduleOf[account].totalWithdrawn);

        _totalSupply = _totalSupply.sub(vestingAmount);
        _balances[account] = 0;
        stakingToken.safeTransfer(account, amount);

        vestingScheduleOf[account].revokable = false;

        emit VestingScheduleRevoked(
            account, 
            vestingAmount - vestingScheduleOf[account].totalWithdrawn, 
            vestingScheduleOf[account].cliff, 
            vestingScheduleOf[account].end, 
            vestingScheduleOf[account].totalVesting, 
            false
        );
    }

    /// @notice Stakes the specified amount of stakingToken to this contract.
    /// @dev Intended to be private, so only callable via createVestingSchedule().
    /// @param amount The amount of the _rewardsToken to deposit.
    /// @param account The account to stake for.
    function _stake(uint256 amount, address account) private nonReentrant updateReward(account) {
        require(amount > 0, "ZivoeRewardsVesting::_stake() amount == 0");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Staked(account, amount);
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
        if (reward > 0) {
            rewards[_msgSender()][_rewardsToken] = 0;
            IERC20(_rewardsToken).safeTransfer(_msgSender(), reward);
            emit RewardDistributed(_msgSender(), _rewardsToken, reward);
        }
    }

    /// @notice Withdraws the available amount of stakingToken from this contract.
    function withdraw() public nonReentrant updateReward(_msgSender()) {
        uint256 amount = amountWithdrawable(_msgSender());
        require(amount > 0, "ZivoeRewardsVesting::withdraw() amountWithdrawable(_msgSender()) == 0");
        
        vestingScheduleOf[_msgSender()].totalWithdrawn += amount;
        vestingTokenAllocated -= amount;

        _totalSupply = _totalSupply.sub(amount);
        _balances[_msgSender()] = _balances[_msgSender()].sub(amount);
        stakingToken.safeTransfer(_msgSender(), amount);

        emit Withdrawn(_msgSender(), amount);
    }

}
