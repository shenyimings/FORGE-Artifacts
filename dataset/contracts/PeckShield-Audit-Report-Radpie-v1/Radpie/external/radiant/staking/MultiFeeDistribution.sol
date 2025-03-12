// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../interfaces/radiant/IChefIncentivesController.sol";
import "../../../interfaces/radiant/IMiddleFeeDistribution.sol";
import "../../../interfaces/radiant/IBountyManager.sol";
import { IMultiFeeDistribution } from "../../../interfaces/radiant/IMultiFeeDistribution.sol";
import "../../../interfaces/radiant/IMintableToken.sol";
import "../../../interfaces/radiant/ILockerList.sol";
import "../../../interfaces/radiant/LockedBalance.sol";

import "hardhat/console.sol";

/// @title Multi Fee Distribution Contract
/// @author Radiant
/// @dev All function calls are currently implemented without side effects
contract MultiFeeDistribution is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableToken;

    address private _priceProvider;

    /********************** Constants ***********************/

    uint256 public constant QUART = 25000; //  25%
    uint256 public constant HALF = 65000; //  65%
    uint256 public constant WHOLE = 100000; // 100%

    /// @notice Proportion of burn amount
    uint256 public burn = 10000;

    /// @notice Duration that rewards are streamed over
    uint256 public rewardsDuration = 604800;

    /// @notice Duration that rewards loop back
    uint256 public rewardsLookback = 86400;

    /// @notice Multiplier for earnings, fixed to 1
    // uint256 public constant DEFAULT_MUTLIPLIER = 1;

    /// @notice Default lock index
    uint256 public constant DEFAULT_LOCK_INDEX = 1;

    /// @notice Duration of lock/earned penalty period, used for earnings
    uint256 public defaultLockDuration = 7776000;

    /// @notice Duration of vesting RDNT
    uint256 public vestDuration = 7776000;

    address public rewardConverter;

    /********************** Contract Addresses ***********************/

    /// @notice Address of Middle Fee Distribution Contract
    IMiddleFeeDistribution public middleFeeDistribution;

    /// @notice Address of CIC contract
    IChefIncentivesController public incentivesController;

    /// @notice Address of RDNT
    IMintableToken public rdntToken;

    /// @notice Address of LP token
    address public stakingToken;

    // Address of Lock Zapper
    address internal lockZap;

    /********************** Lock & Earn Info ***********************/

    // Private mappings for balance data
    mapping(address => Balances) private balances;
    mapping(address => LockedBalance[]) internal userLocks;
    mapping(address => LockedBalance[]) private userEarnings;

    /// @notice Total locked value
    uint256 public lockedSupply;

    /// @notice Total locked value in multipliers
    uint256 public lockedSupplyWithMultiplier;

    // Time lengths
    uint256[] internal lockPeriod;

    // Multipliers
    uint256[] internal rewardMultipliers;

    /********************** Reward Info ***********************/

    /// @notice Reward tokens being distributed
    address[] public rewardTokens;

    /// @notice Reward data per token
    mapping(address => Reward) public rewardData;

    /// @notice user -> reward token -> rpt; RPT for paid amount
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;

    /// @notice user -> reward token -> amount; used to store reward amount
    mapping(address => mapping(address => uint256)) public rewards;

    /********************** Other Info ***********************/

    /// @notice DAO wallet
    address public daoTreasury;

    /// @notice treasury wallet
    address public startfleetTreasury;

    /// @notice Addresses approved to call mint
    mapping(address => bool) public minters;

    // Addresses to relock
    mapping(address => bool) public autoRelockDisabled;

    // Default lock index for relock
    mapping(address => uint256) public defaultLockIndex;

    /// @notice Flag to prevent more minter addings
    bool public mintersAreSet;

    // Users list
    ILockerList public userlist;

    mapping(address => uint256) public lastClaimTime;

    address public bountyManager;

    // to prevent unbounded lock length iteration during withdraw/clean

    /********************** Events ***********************/

    //event RewardAdded(uint256 reward);
    // event Staked(address indexed user, uint256 amount, bool locked);
    event Locked(address indexed user, uint256 amount, uint256 lockedBalance, bool isLP);
    event Withdrawn(
        address indexed user,
        uint256 receivedAmount,
        uint256 lockedBalance,
        uint256 penalty,
        uint256 burn,
        bool isLP
    );
    event RewardPaid(address indexed user, address indexed rewardToken, uint256 reward);
    event IneligibleRewardRemoved(
        address indexed user,
        address indexed rewardToken,
        uint256 reward
    );
    event RewardsDurationUpdated(address token, uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event Relocked(address indexed user, uint256 amount, uint256 lockIndex);

    constructor(
        address _rdntToken,
        address _lockZap,
        address _dao,
        address _userlist,
        address priceProvider
    ) {
        rdntToken = IMintableToken(_rdntToken);
        lockZap = _lockZap;
        daoTreasury = _dao;
        _priceProvider = priceProvider;
        userlist = ILockerList(_userlist);
        rewardTokens.push(_rdntToken);
        rewardData[_rdntToken].lastUpdateTime = block.timestamp;
    }

    /********************** Setters ***********************/

    /**
     * @notice Set minters
     * @dev Can be called only once
     */
    function setMinters(address[] memory _minters) external {
        require(!mintersAreSet, "minters set");
        for (uint256 i; i < _minters.length; i++) {
            require(_minters[i] != address(0), "minter is 0 address");
            minters[_minters[i]] = true;
        }
        mintersAreSet = true;
    }

    function setBountyManager(address _bounty) external {
        require(_bounty != address(0), "bounty is 0 address");
        bountyManager = _bounty;
        minters[_bounty] = true;
    }

    function addRewardConverter(address _rewardConverter) external {
        require(_rewardConverter != address(0), "rewardConverter is 0 address");
        rewardConverter = _rewardConverter;
    }

    /**
     * @notice Add a new reward token to be distributed to stakers.
     */
    function setLockTypeInfo(
        uint256[] memory _lockPeriod,
        uint256[] memory _rewardMultipliers
    ) external {
        require(_lockPeriod.length == _rewardMultipliers.length, "invalid lock period");
        delete lockPeriod;
        delete rewardMultipliers;
        for (uint256 i = 0; i < _lockPeriod.length; i += 1) {
            lockPeriod.push(_lockPeriod[i]);
            rewardMultipliers.push(_rewardMultipliers[i]);
        }
    }

    /**
     * @notice Set CIC, MFD and Treasury.
     */
    function setAddresses(
        IChefIncentivesController _controller,
        IMiddleFeeDistribution _middleFeeDistribution,
        address _treasury
    ) external {
        require(address(_controller) != address(0), "controller is 0 address");
        require(address(_middleFeeDistribution) != address(0), "mfd is 0 address");
        incentivesController = _controller;
        middleFeeDistribution = _middleFeeDistribution;
        startfleetTreasury = _treasury;
    }

    /**
     * @notice Set LP token.
     */
    function setLPToken(address _stakingToken) external {
        require(_stakingToken != address(0), "_stakingToken is 0 address");
        require(stakingToken == address(0), "already set");
        stakingToken = _stakingToken;
    }

    /**
     * @notice Add a new reward token to be distributed to stakers.
     */
    function addReward(address _rewardToken) external {
        require(_rewardToken != address(0), "rewardToken is 0 address");
        require(minters[msg.sender], "!minter");
        require(rewardData[_rewardToken].lastUpdateTime == 0, "already added");
        rewardTokens.push(_rewardToken);
        rewardData[_rewardToken].lastUpdateTime = block.timestamp;
        rewardData[_rewardToken].periodFinish = block.timestamp + 7 days;
    }

    function updateRewardInfo(
        address[] memory _token,
        uint256[] memory _rewardPerSecond,
        uint256[] memory _rewardPerTokenStored,
        uint256[] memory _balance
    ) public {
        for (uint8 i = 0; i < _token.length; i++) {
            rewardData[_token[i]].rewardPerSecond = _rewardPerSecond[i];
            rewardData[_token[i]].rewardPerTokenStored = _rewardPerTokenStored[i];
            rewardData[_token[i]].balance = _balance[i];
        }
    }

    /********************** View functions ***********************/

    /**
     * @notice Set default lock type index for user relock.
     */
    function setDefaultRelockTypeIndex(uint256 _index) external {
        require(_index < lockPeriod.length, "invalid type");
        defaultLockIndex[msg.sender] = _index;
    }

    function getLockDurations() external view returns (uint256[] memory) {
        return lockPeriod;
    }

    function getLockMultipliers() external view returns (uint256[] memory) {
        return rewardMultipliers;
    }

    /**
     * @notice Set relock status
     */
    function setRelock(bool _status) external virtual {
        autoRelockDisabled[msg.sender] = !_status;
    }

    /**
     * @notice Returns all locks of a user.
     */
    function lockInfo(address user) external view returns (LockedBalance[] memory) {
        return userLocks[user];
    }

    /**
     * @notice Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders.
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
        require(rewardData[tokenAddress].lastUpdateTime == 0, "active reward");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /**
     * @notice Withdraw and restake assets.
     */
    function relock() external virtual {
        uint256 amount = _withdrawExpiredLocksFor(
            msg.sender,
            true,
            true,
            userLocks[msg.sender].length
        );
        _stake(amount, msg.sender, defaultLockIndex[msg.sender], false);
        emit Relocked(msg.sender, amount, defaultLockIndex[msg.sender]);
    }

    /**
     * @notice Total balance of an account, including unlocked, locked and earned tokens.
     */
    function totalBalance(address user) external view returns (uint256 amount) {
        if (stakingToken == address(rdntToken)) {
            return balances[user].total;
        }
        return balances[user].locked;
    }

    /**
     * @notice Information on a user's lockings
     * @return total balance of locks
     * @return unlockable balance
     * @return locked balance
     * @return lockedWithMultiplier
     * @return lockData which is an array of locks
     */
    function lockedBalances(
        address user
    )
        public
        view
        returns (
            uint256 total,
            uint256 unlockable,
            uint256 locked,
            uint256 lockedWithMultiplier,
            LockedBalance[] memory lockData
        )
    {
        LockedBalance[] storage locks = userLocks[user];
        uint256 idx;
        for (uint256 i = 0; i < locks.length; i++) {
            if (locks[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    lockData = new LockedBalance[](locks.length - i);
                }
                lockData[idx] = locks[i];
                idx++;
                locked = locked.add(locks[i].amount);
                lockedWithMultiplier = lockedWithMultiplier.add(
                    locks[i].amount.mul(locks[i].multiplier)
                );
            } else {
                unlockable = unlockable.add(locks[i].amount);
            }
        }
        return (balances[user].locked, unlockable, locked, lockedWithMultiplier, lockData);
    }

    /**
     * @notice Earnings which is locked yet
     * @dev Earned balances may be withdrawn immediately for a 50% penalty.
     * @return total earnings
     * @return unlocked earnings
     * @return earningsData which is an array of all infos
     */
    function earnedBalances(
        address user
    ) public view returns (uint256 total, uint256 unlocked, EarnedBalance[] memory earningsData) {
        unlocked = balances[user].unlocked;
        LockedBalance[] storage earnings = userEarnings[user];
        uint256 idx;
        for (uint256 i = 0; i < earnings.length; i++) {
            if (earnings[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    earningsData = new EarnedBalance[](earnings.length - i);
                }
                (, uint256 penaltyAmount, , ) = ieeWithdrawableBalances(
                    user,
                    earnings[i].unlockTime
                );
                earningsData[idx].amount = earnings[i].amount;
                earningsData[idx].unlockTime = earnings[i].unlockTime;
                earningsData[idx].penalty = penaltyAmount;
                idx++;
                total = total.add(earnings[i].amount);
            } else {
                unlocked = unlocked.add(earnings[i].amount);
            }
        }
        return (total, unlocked, earningsData);
    }

    /**
     * @notice Final balance received and penalty balance paid by user upon calling exit.
     * @dev This is earnings, not locks.
     */
    function withdrawableBalance(
        address user
    ) public view returns (uint256 amount, uint256 penaltyAmount, uint256 burnAmount) {
        uint256 earned = balances[user].earned;
        if (earned > 0) {
            uint256 length = userEarnings[user].length;
            for (uint256 i = 0; i < length; i++) {
                uint256 earnedAmount = userEarnings[user][i].amount;
                if (earnedAmount == 0) continue;
                (, , uint256 newPenaltyAmount, uint256 newBurnAmount) = _penaltyInfo(
                    userEarnings[user][i]
                );
                penaltyAmount = penaltyAmount.add(newPenaltyAmount);
                burnAmount = burnAmount.add(newBurnAmount);
            }
        }
        amount = balances[user].unlocked.add(earned).sub(penaltyAmount);
        return (amount, penaltyAmount, burnAmount);
    }

    function _penaltyInfo(
        LockedBalance memory earning
    )
        internal
        view
        returns (uint256 amount, uint256 penaltyFactor, uint256 penaltyAmount, uint256 burnAmount)
    {
        if (earning.unlockTime > block.timestamp) {
            // 90% on day 1, decays to 25% on day 90
            penaltyFactor = earning.unlockTime.sub(block.timestamp).mul(HALF).div(vestDuration).add(
                QUART
            ); // 25% + timeLeft/vestDuration * 65%
        }
        penaltyAmount = earning.amount.mul(penaltyFactor).div(WHOLE);
        burnAmount = penaltyAmount.mul(burn).div(WHOLE);
        amount = earning.amount.sub(penaltyAmount);
    }

    /********************** Reward functions ***********************/

    /**
     * @notice Reward amount of the duration.
     * @param _rewardToken for the reward
     */
    function getRewardForDuration(address _rewardToken) external view returns (uint256) {
        return rewardData[_rewardToken].rewardPerSecond.mul(rewardsDuration).div(1e12);
    }

    /**
     * @notice Returns reward applicable timestamp.
     */
    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256) {
        uint256 periodFinish = rewardData[_rewardToken].periodFinish;
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Reward amount per token
     * @dev Reward is distributed only for locks.
     * @param _rewardToken for reward
     */
    function rewardPerToken(address _rewardToken) public view returns (uint256 rptStored) {
        rptStored = rewardData[_rewardToken].rewardPerTokenStored;

        if (lockedSupplyWithMultiplier > 0) {
            uint256 newReward = lastTimeRewardApplicable(_rewardToken)
                .sub(rewardData[_rewardToken].lastUpdateTime)
                .mul(rewardData[_rewardToken].rewardPerSecond);
            rptStored = rptStored.add(newReward.mul(1e18).div(lockedSupplyWithMultiplier));
        }
    }

    /**
     * @notice Address and claimable amount of all reward tokens for the given account.
     * @param account for rewards
     */
    function claimableRewards(
        address account
    ) public view returns (IFeeDistribution.RewardData[] memory rewardsData) {
        rewardsData = new IFeeDistribution.RewardData[](rewardTokens.length);
        for (uint256 i = 0; i < rewardsData.length; i++) {
            rewardsData[i].token = rewardTokens[i];
            rewardsData[i].amount = _earned(
                account,
                rewardsData[i].token,
                balances[account].lockedWithMultiplier,
                rewardPerToken(rewardsData[i].token)
            ).div(1e12);
        }
        return rewardsData;
    }

    /********************** Operate functions ***********************/

    /**
     * @notice Stake tokens to receive rewards.
     * @dev Locked tokens cannot be withdrawn for defaultLockDuration and are eligible to receive rewards.
     */
    function stake(uint256 amount, address onBehalfOf, uint256 typeIndex) external {
        _stake(amount, onBehalfOf, typeIndex, false);
    }

    function _stake(uint256 amount, address onBehalfOf, uint256 typeIndex, bool isRelock) internal {
        if (amount == 0) return;
        /* if (bountyManager != address(0)) {
			require(amount >= IBountyManager(bountyManager).minDLPBalance(), "min stake amt not met");
		} */
        require(typeIndex < lockPeriod.length, "invalid index");

        _updateReward(onBehalfOf);

        uint256 transferAmount = amount;
        if (userLocks[onBehalfOf].length != 0) {
            //if user has any locks
            if (userLocks[onBehalfOf][0].unlockTime <= block.timestamp) {
                //if users soonest unlock has already elapsed
                if (onBehalfOf == msg.sender || msg.sender == lockZap) {
                    //if the user is msg.sender or the lockzap contract
                    uint256 withdrawnAmt;
                    if (!autoRelockDisabled[onBehalfOf]) {
                        withdrawnAmt = _withdrawExpiredLocksFor(
                            onBehalfOf,
                            true,
                            false,
                            userLocks[onBehalfOf].length
                        );
                        amount = amount.add(withdrawnAmt);
                    } else {
                        _withdrawExpiredLocksFor(
                            onBehalfOf,
                            true,
                            true,
                            userLocks[onBehalfOf].length
                        );
                    }
                }
            }
        }
        Balances storage bal = balances[onBehalfOf];
        bal.total = bal.total.add(amount);

        bal.locked = bal.locked.add(amount);
        lockedSupply = lockedSupply.add(amount);

        bal.lockedWithMultiplier = bal.lockedWithMultiplier.add(
            amount.mul(rewardMultipliers[typeIndex])
        );
        lockedSupplyWithMultiplier = lockedSupplyWithMultiplier.add(
            amount.mul(rewardMultipliers[typeIndex])
        );

        _insertLock(
            onBehalfOf,
            LockedBalance({
                amount: amount,
                unlockTime: block.timestamp.add(lockPeriod[typeIndex]),
                multiplier: rewardMultipliers[typeIndex],
                duration: lockPeriod[typeIndex]
            })
        );

        //userlist.addToList(onBehalfOf);

        if (!isRelock) {
            IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), transferAmount);
        }

        incentivesController.afterLockUpdate(onBehalfOf);
        emit Locked(
            onBehalfOf,
            amount,
            balances[onBehalfOf].locked,
            stakingToken != address(rdntToken)
        );
    }

    function _insertLock(address _user, LockedBalance memory newLock) internal {
        LockedBalance[] storage locks = userLocks[_user];
        uint256 length = locks.length;
        uint256 i;
        while (i < length && locks[i].unlockTime < newLock.unlockTime) {
            i = i + 1;
        }
        locks.push(newLock);
        for (uint256 j = length; j > i; j -= 1) {
            locks[j] = locks[j - 1];
        }
        locks[i] = newLock;
    }

    /**
     * @notice Add to earnings
     * @dev Minted tokens receive rewards normally but incur a 50% penalty when
     *  withdrawn before vestDuration has passed.
     */
    function mint(address user, uint256 amount, bool withPenalty) external {
        require(minters[msg.sender], "!minter");
        if (amount == 0) return;

        if (user == address(this)) {
            // minting to this contract adds the new tokens as incentives for lockers
            _notifyReward(address(rdntToken), amount);
            return;
        }

        Balances storage bal = balances[user];
        bal.total = bal.total.add(amount);
        if (withPenalty) {
            bal.earned = bal.earned.add(amount);
            LockedBalance[] storage earnings = userEarnings[user];
            uint256 unlockTime = block.timestamp.add(vestDuration);
            earnings.push(
                LockedBalance({
                    amount: amount,
                    unlockTime: unlockTime,
                    multiplier: 1,
                    duration: vestDuration
                })
            );
        } else {
            bal.unlocked = bal.unlocked.add(amount);
        }
        //emit Staked(user, amount, false);
    }

    /**
     * @notice Withdraw tokens from earnings and unlocked.
     * @dev First withdraws unlocked tokens, then earned tokens. Withdrawing earned tokens
     *  incurs a 50% penalty which is distributed based on locked balances.
     */
    function withdraw(uint256 amount) external {
        address _address = msg.sender;
        require(amount != 0, "amt cannot be 0");

        uint256 penaltyAmount;
        uint256 burnAmount;
        Balances storage bal = balances[_address];

        if (amount <= bal.unlocked) {
            bal.unlocked = bal.unlocked.sub(amount);
        } else {
            uint256 remaining = amount.sub(bal.unlocked);
            require(bal.earned >= remaining, "invalid earned");
            bal.unlocked = 0;
            uint256 sumEarned = bal.earned;
            uint256 i;
            for (i = 0; ; i++) {
                uint256 earnedAmount = userEarnings[_address][i].amount;
                if (earnedAmount == 0) continue;
                (, uint256 penaltyFactor, , ) = _penaltyInfo(userEarnings[_address][i]);

                // Amount required from this lock, taking into account the penalty
                uint256 requiredAmount = remaining.mul(WHOLE).div(WHOLE.sub(penaltyFactor));
                if (requiredAmount >= earnedAmount) {
                    requiredAmount = earnedAmount;
                    remaining = remaining.sub(
                        earnedAmount.mul(WHOLE.sub(penaltyFactor)).div(WHOLE)
                    ); // remaining -= earned * (1 - pentaltyFactor)
                    if (remaining == 0) i++;
                } else {
                    userEarnings[_address][i].amount = earnedAmount.sub(requiredAmount);
                    remaining = 0;
                }
                sumEarned = sumEarned.sub(requiredAmount);

                penaltyAmount = penaltyAmount.add(requiredAmount.mul(penaltyFactor).div(WHOLE)); // penalty += amount * penaltyFactor
                burnAmount = burnAmount.add(penaltyAmount.mul(burn).div(WHOLE)); // burn += penalty * burnFactor

                if (remaining == 0) {
                    break;
                } else {
                    require(sumEarned != 0, "0 earned");
                }
            }
            if (i > 0) {
                for (uint256 j = i; j < userEarnings[_address].length; j++) {
                    userEarnings[_address][j - i] = userEarnings[_address][j];
                }
                for (uint256 j = 0; j < i; j++) {
                    userEarnings[_address].pop();
                }
            }
            bal.earned = sumEarned;
        }

        // Update values
        bal.total = bal.total.sub(amount).sub(penaltyAmount);

        _withdrawTokens(_address, amount, penaltyAmount, burnAmount, false);
    }

    function ieeWithdrawableBalances(
        address user,
        uint256 unlockTime
    )
        internal
        view
        returns (uint256 amount, uint256 penaltyAmount, uint256 burnAmount, uint256 index)
    {
        for (uint256 i = 0; i < userEarnings[user].length; i++) {
            if (userEarnings[user][i].unlockTime == unlockTime) {
                (amount, , penaltyAmount, burnAmount) = _penaltyInfo(userEarnings[user][i]);
                index = i;
                break;
            }
        }
    }

    /**
     * @notice Withdraw individual unlocked balance and earnings, optionally claim pending rewards.
     */
    function individualEarlyExit(bool claimRewards, uint256 unlockTime) external {
        address onBehalfOf = msg.sender;
        require(unlockTime > block.timestamp, "!unlockTime");
        (
            uint256 amount,
            uint256 penaltyAmount,
            uint256 burnAmount,
            uint256 index
        ) = ieeWithdrawableBalances(onBehalfOf, unlockTime);

        if (index >= userEarnings[onBehalfOf].length) {
            return;
        }

        for (uint256 i = index + 1; i < userEarnings[onBehalfOf].length; i++) {
            userEarnings[onBehalfOf][i - 1] = userEarnings[onBehalfOf][i];
        }
        userEarnings[onBehalfOf].pop();

        Balances storage bal = balances[onBehalfOf];
        bal.total = bal.total.sub(amount).sub(penaltyAmount);
        bal.earned = bal.earned.sub(amount).sub(penaltyAmount);

        _withdrawTokens(onBehalfOf, amount, penaltyAmount, burnAmount, claimRewards);
    }

    /**
     * @notice Withdraw full unlocked balance and earnings, optionally claim pending rewards.
     */
    function exit(bool claimRewards) external {
        address onBehalfOf = msg.sender;
        (uint256 amount, uint256 penaltyAmount, uint256 burnAmount) = withdrawableBalance(
            onBehalfOf
        );

        delete userEarnings[onBehalfOf];

        Balances storage bal = balances[onBehalfOf];
        bal.total = bal.total.sub(bal.unlocked).sub(bal.earned);
        bal.unlocked = 0;
        bal.earned = 0;

        _withdrawTokens(onBehalfOf, amount, penaltyAmount, burnAmount, claimRewards);
    }

    /**
     * @notice Claim all pending staking rewards.
     */
    function getReward(address[] memory _rewardTokens) public {
        _updateReward(msg.sender);
        _getReward(msg.sender, _rewardTokens);
    }

    /**
     * @notice Claim all pending staking rewards.
     */
    function getAllRewards() external {
        return getReward(rewardTokens);
    }

    /**
     * @notice Calculate earnings.
     */
    function _earned(
        address _user,
        address _rewardToken,
        uint256 _balance,
        uint256 _currentRewardPerToken
    ) internal view returns (uint256 earnings) {
        earnings = rewards[_user][_rewardToken];
        uint256 realRPT = _currentRewardPerToken.sub(userRewardPerTokenPaid[_user][_rewardToken]);
        earnings = earnings.add(_balance.mul(realRPT).div(1e18));
    }

    /**
     * @notice Update user reward info.
     */
    function _updateReward(address account) public {
        uint256 balance = balances[account].lockedWithMultiplier;
        uint256 length = rewardTokens.length;
        for (uint256 i = 0; i < length; i++) {
            address token = rewardTokens[i];
            uint256 rpt = rewardPerToken(token);

            Reward storage r = rewardData[token];
            r.rewardPerTokenStored = rpt;
            r.lastUpdateTime = lastTimeRewardApplicable(token);

            if (account != address(this)) {
                rewards[account][token] = _earned(account, token, balance, rpt);
                userRewardPerTokenPaid[account][token] = rpt;
            }
        }
    }

    /**
     * @notice Add new reward.
     * @dev If prev reward period is not done, then it resets `rewardPerSecond` and restarts period
     */
    function _notifyReward(address _rewardToken, uint256 reward) internal {
        Reward storage r = rewardData[_rewardToken];
        if (block.timestamp >= r.periodFinish) {
            r.rewardPerSecond = reward.mul(1e12).div(rewardsDuration);
        } else {
            uint256 remaining = r.periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(r.rewardPerSecond).div(1e12);
            r.rewardPerSecond = reward.add(leftover).mul(1e12).div(rewardsDuration);
        }

        r.lastUpdateTime = block.timestamp;
        r.periodFinish = block.timestamp.add(rewardsDuration);
        r.balance = r.balance.add(reward);
    }

    /**
     * @notice Notify unseen rewards.
     * @dev for rewards other than stakingToken, every 24 hours we check if new
     *  rewards were sent to the contract or accrued via aToken interest.
     */
    function _notifyUnseenReward(address token) internal {
        require(token != address(0), "Invalid Token");
        if (token == address(rdntToken)) {
            return;
        }
        Reward storage r = rewardData[token];
        uint256 periodFinish = r.periodFinish;
        require(periodFinish != 0, "invalid period finish");
        if (periodFinish < block.timestamp.add(rewardsDuration - rewardsLookback)) {
            uint256 unseen = IERC20(token).balanceOf(address(this)).sub(r.balance);
            if (unseen > 0) {
                _notifyReward(token, unseen);
            }
        }
    }

    function onUpgrade() public {}

    function setLookback(uint256 _lookback) public {
        rewardsLookback = _lookback;
    }

    /**
     * @notice User gets reward
     */
    function _getReward(address _user, address[] memory _rewardTokens) internal {
        middleFeeDistribution.forwardReward(_rewardTokens);
        uint256 length = _rewardTokens.length;
        for (uint256 i; i < length; i++) {
            address token = _rewardTokens[i];
            _notifyUnseenReward(token);
            uint256 reward = rewards[_user][token].div(1e12);
            if (reward > 0) {
                rewards[_user][token] = 0;
                rewardData[token].balance = rewardData[token].balance.sub(reward);

                IERC20(token).safeTransfer(_user, reward);
                emit RewardPaid(_user, token, reward);
            }
        }
    }

    /**
     * @notice Withdraw tokens from MFD
     */
    function _withdrawTokens(
        address onBehalfOf,
        uint256 amount,
        uint256 penaltyAmount,
        uint256 burnAmount,
        bool claimRewards
    ) internal {
        require(onBehalfOf == msg.sender, "onBehalfOf != sender");
        _updateReward(onBehalfOf);

        rdntToken.safeTransfer(onBehalfOf, amount);
        if (penaltyAmount > 0) {
            if (burnAmount > 0) {
                rdntToken.safeTransfer(startfleetTreasury, burnAmount);
            }
            rdntToken.safeTransfer(daoTreasury, penaltyAmount.sub(burnAmount));
        }

        if (claimRewards) {
            _getReward(onBehalfOf, rewardTokens);
            lastClaimTime[onBehalfOf] = block.timestamp;
        }

        emit Withdrawn(
            onBehalfOf,
            amount,
            balances[onBehalfOf].locked,
            penaltyAmount,
            burnAmount,
            stakingToken != address(rdntToken)
        );
    }

    /********************** Eligibility + Disqualification ***********************/

    /**
     * @notice Withdraw all lockings tokens where the unlock time has passed
     */
    function _cleanWithdrawableLocks(
        address user,
        uint256 totalLock,
        uint256 totalLockWithMultiplier,
        uint256 limit
    ) internal returns (uint256 lockAmount, uint256 lockAmountWithMultiplier) {
        LockedBalance[] storage locks = userLocks[user];

        if (locks.length != 0) {
            uint256 length = locks.length <= limit ? locks.length : limit;
            for (uint256 i = 0; i < length; ) {
                if (locks[i].unlockTime <= block.timestamp) {
                    lockAmount = lockAmount.add(locks[i].amount);
                    lockAmountWithMultiplier = lockAmountWithMultiplier.add(
                        locks[i].amount.mul(locks[i].multiplier)
                    );
                    locks[i] = locks[locks.length - 1];
                    locks.pop();
                    length = length.sub(1);
                } else {
                    i = i + 1;
                }
            }
            if (locks.length == 0) {
                lockAmount = totalLock;
                lockAmountWithMultiplier = totalLockWithMultiplier;
                delete userLocks[user];

                userlist.removeFromList(user);
            }
        }
    }

    /**
     * @notice Withdraw all currently locked tokens where the unlock time has passed.
     * @param _address of the user.
     */
    function _withdrawExpiredLocksFor(
        address _address,
        bool isRelockAction,
        bool doTransfer,
        uint256 limit
    ) internal returns (uint256 amount) {
        _updateReward(_address);

        uint256 amountWithMultiplier;
        Balances storage bal = balances[_address];
        (amount, amountWithMultiplier) = _cleanWithdrawableLocks(
            _address,
            bal.locked,
            bal.lockedWithMultiplier,
            limit
        );
        bal.locked = bal.locked.sub(amount);
        bal.lockedWithMultiplier = bal.lockedWithMultiplier.sub(amountWithMultiplier);
        bal.total = bal.total.sub(amount);
        lockedSupply = lockedSupply.sub(amount);
        lockedSupplyWithMultiplier = lockedSupplyWithMultiplier.sub(amountWithMultiplier);

        if (!isRelockAction && !autoRelockDisabled[_address]) {
            _stake(amount, _address, defaultLockIndex[_address], true);
        } else {
            if (doTransfer) {
                IERC20(stakingToken).safeTransfer(_address, amount);
                incentivesController.afterLockUpdate(_address);
                emit Withdrawn(
                    _address,
                    amount,
                    balances[_address].locked,
                    0,
                    0,
                    stakingToken != address(rdntToken)
                );
            }
        }
        return amount;
    }

    /**
     * @notice Withdraw all currently locked tokens where the unlock time has passed.
     */
    function withdrawExpiredLocksFor(address _address) external returns (uint256) {
        return _withdrawExpiredLocksFor(_address, false, true, userLocks[_address].length);
    }

    function withdrawExpiredLocksForWithOptions(
        address _address,
        uint256 _limit,
        bool _ignoreRelock
    ) external returns (uint256) {
        if (_limit == 0) _limit = userLocks[_address].length;

        return _withdrawExpiredLocksFor(_address, _ignoreRelock, true, _limit);
    }

    function zapVestingToLp(address _user) external returns (uint256 zapped) {
        require(msg.sender == lockZap, "!lockZap");

        _updateReward(_user);

        LockedBalance[] storage earnings = userEarnings[_user];
        for (uint256 i = earnings.length; i > 0; i -= 1) {
            if (earnings[i - 1].unlockTime > block.timestamp) {
                zapped = zapped.add(earnings[i - 1].amount);
                earnings.pop();
            } else {
                break;
            }
        }

        rdntToken.safeTransfer(lockZap, zapped);

        Balances storage bal = balances[_user];
        bal.earned = bal.earned.sub(zapped);
        bal.total = bal.total.sub(zapped);

        return zapped;
    }

    /**
     * @notice Claims bounty.
     * @dev Remove expired locks
     * @param _user address.
     */
    function claimBounty(address _user, bool _execute) public returns (bool issueBaseBounty) {
        require(msg.sender == address(bountyManager), "!bountyManager");

        (, uint256 unlockable, , , ) = lockedBalances(_user);
        if (unlockable == 0) {
            return (false);
        } else {
            issueBaseBounty = true;
        }

        if (!_execute) {
            return (issueBaseBounty);
        }
        // Withdraw the user's expried locks
        _withdrawExpiredLocksFor(_user, false, true, userLocks[_user].length);
    }
}
