// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../interfaces/radiant/IMultiFeeDistribution.sol";
import "../../../interfaces/radiant/IEligibilityDataProvider.sol";
import "../../../interfaces/radiant/ILeverager.sol";
import "../../../interfaces/radiant/IOnwardIncentivesController.sol";
import "../../../interfaces/radiant/IMiddleFeeDistribution.sol";

import "hardhat/console.sol";

// based on the Sushi MasterChef
// https://github.com/sushiswap/sushiswap/blob/master/contracts/MasterChef.sol
contract ChefIncentivesController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    // reward = user.`amount` * pool.`accRewardPerShare` - `rewardDebt`
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastClaimTime;
    }

    // Info of each pool.
    struct PoolInfo {
        uint256 totalSupply;
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardTime; // Last second that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewards per share, times ACC_REWARD_PRECISION. See below.
        IOnwardIncentivesController onwardIncentives;
    }

    // Info about token emissions for a given time period.
    struct EmissionPoint {
        uint128 startTimeOffset;
        uint128 rewardsPerSecond;
    }

    // Emitted when rewardPerSecond is updated
    event RewardsPerSecondUpdated(uint256 indexed rewardsPerSecond, bool persist);

    event BalanceUpdated(
        address indexed token,
        address indexed user,
        uint256 balance,
        uint256 totalSupply
    );

    event EmissionScheduleAppended(uint256[] startTimeOffsets, uint256[] rewardsPerSeconds);

    event ChefReserveLow(uint256 _balance);

    event ChefReserveEmpty(uint256 _balance);

    event Disqualified(address indexed user);

    // multiplier for reward calc
    uint256 private constant ACC_REWARD_PRECISION = 1e12;

    // Data about the future reward rates. emissionSchedule stored in chronological order,
    // whenever the number of blocks since the start block exceeds the next block offset a new
    // reward rate is applied.
    EmissionPoint[] public emissionSchedule;

    // If true, keep this new reward rate indefinitely
    // If false, keep this reward rate until the next scheduled block offset, then return to the schedule.
    bool public persistRewardsPerSecond;

    /********************** Emission Info ***********************/

    // Array of tokens for reward
    address[] public registeredTokens;

    // Current reward per second
    uint256 public rewardsPerSecond;

    // last RPS, used during refill after reserve empty
    uint256 public lastRPS;

    // Index in emission schedule which the last rewardsPerSeconds was used
    // only used for scheduled rewards
    uint256 public emissionScheduleIndex;

    // Info of each pool.
    mapping(address => PoolInfo) public poolInfo;
    mapping(address => bool) private validRTokens;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    // token => user => Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;

    // user => base claimable balance
    mapping(address => uint256) public userBaseClaimable;

    // MFD, bounties, AC, middlefee
    mapping(address => bool) public eligibilityExempt;

    // The block number when reward mining starts.
    uint256 public startTime;

    bool public eligibilityEnabled;

    address public poolConfigurator;
    uint256 public depositedRewards;
    uint256 public accountedRewards;
    uint256 public lastAllPoolUpdate;

    IMiddleFeeDistribution public rewardMinter;
    IEligibilityDataProvider public eligibleDataProvider;
    ILeverager public leverager;
    address public bountyManager;

    struct EndingTime {
        uint256 estimatedTime;
        uint256 lastUpdatedTime;
        uint256 updateCadence;
    }

    EndingTime public endingTime;

    constructor(
        address _poolConfigurator,
        IEligibilityDataProvider _eligibleDataProvider,
        IMiddleFeeDistribution _rewardMinter,
        uint256 _rewardsPerSecond
    ) {
        poolConfigurator = _poolConfigurator;
        eligibleDataProvider = _eligibleDataProvider;
        rewardMinter = _rewardMinter;
        rewardsPerSecond = _rewardsPerSecond;
        persistRewardsPerSecond = true;

        eligibilityEnabled = true;
    }

    function poolLength() public view returns (uint256) {
        return registeredTokens.length;
    }

    function _getMfd() internal view returns (IMultiFeeDistribution mfd) {
        address multiFeeDistribution = rewardMinter.getMultiFeeDistributionAddress();
        mfd = IMultiFeeDistribution(multiFeeDistribution);
    }

    function setOnwardIncentives(address _token, IOnwardIncentivesController _incentives) external {
        require(poolInfo[_token].lastRewardTime != 0, "pool doesn't exist");
        poolInfo[_token].onwardIncentives = _incentives;
    }

    function setBountyManager(address _bountyManager) external {
        bountyManager = _bountyManager;
    }

    function setEligibilityEnabled(bool _newVal) external {
        eligibilityEnabled = _newVal;
    }

    /********************** Pool Setup + Admin ***********************/

    function start() public {
        require(startTime == 0, "already started");
        startTime = block.timestamp;
    }

    // Add a new lp to the pool. Can only be called by the poolConfigurator.
    function addPool(address _token, uint256 _allocPoint) external {
        require(msg.sender == poolConfigurator, "not allowed");
        require(poolInfo[_token].lastRewardTime == 0, "pool already exists");
        _updateEmissions();
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        registeredTokens.push(_token);
        poolInfo[_token] = PoolInfo({
            totalSupply: 0,
            allocPoint: _allocPoint,
            lastRewardTime: block.timestamp,
            accRewardPerShare: 0,
            onwardIncentives: IOnwardIncentivesController(address(0))
        });
        validRTokens[_token] = true;
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function batchUpdateAllocPoint(
        address[] calldata _tokens,
        uint256[] calldata _allocPoints
    ) public {
        require(_tokens.length == _allocPoints.length, "params length mismatch");
        _massUpdatePools();
        uint256 _totalAllocPoint = totalAllocPoint;
        for (uint256 i = 0; i < _tokens.length; i++) {
            PoolInfo storage pool = poolInfo[_tokens[i]];
            require(pool.lastRewardTime > 0, "pool doesn't exist");
            _totalAllocPoint = _totalAllocPoint.sub(pool.allocPoint).add(_allocPoints[i]);
            pool.allocPoint = _allocPoints[i];
        }
        totalAllocPoint = _totalAllocPoint;
    }

    /**
     * @notice Sets the reward per second to be distributed. Can only be called by the owner.
     * @dev Its decimals count is ACC_REWARD_PRECISION
     * @param _rewardsPerSecond The amount of reward to be distributed per second.
     */
    function setRewardsPerSecond(uint256 _rewardsPerSecond, bool _persist) external {
        _massUpdatePools();
        rewardsPerSecond = _rewardsPerSecond;
        persistRewardsPerSecond = _persist;
        emit RewardsPerSecondUpdated(_rewardsPerSecond, _persist);
    }

    function setScheduledRewardsPerSecond() internal {
        if (!persistRewardsPerSecond) {
            uint256 length = emissionSchedule.length;
            uint256 i = emissionScheduleIndex;
            uint128 offset = uint128(block.timestamp.sub(startTime));
            for (; i < length && offset >= emissionSchedule[i].startTimeOffset; i++) {}
            if (i > emissionScheduleIndex) {
                emissionScheduleIndex = i;
                _massUpdatePools();
                rewardsPerSecond = uint256(emissionSchedule[i - 1].rewardsPerSecond);
            }
        }
    }

    function setEmissionSchedule(
        uint256[] calldata _startTimeOffsets,
        uint256[] calldata _rewardsPerSecond
    ) external {
        uint256 length = _startTimeOffsets.length;
        require(length > 0 && length == _rewardsPerSecond.length, "empty or mismatch params");

        for (uint256 i = 0; i < length; i++) {
            if (i > 0) {
                require(_startTimeOffsets[i - 1] < _startTimeOffsets[i], "should be ascending");
            }
            require(_startTimeOffsets[i] <= type(uint128).max, "startTimeOffsets > max uint128");
            require(_rewardsPerSecond[i] <= type(uint128).max, "rewardsPerSecond > max uint128");

            if (startTime > 0) {
                require(
                    _startTimeOffsets[i] > block.timestamp.sub(startTime),
                    "invalid start time"
                );
            }
            emissionSchedule.push(
                EmissionPoint({
                    startTimeOffset: uint128(_startTimeOffsets[i]),
                    rewardsPerSecond: uint128(_rewardsPerSecond[i])
                })
            );
        }
        emit EmissionScheduleAppended(_startTimeOffsets, _rewardsPerSecond);
    }

    // function recoverERC20(address tokenAddress, uint256 tokenAmount) external  {
    // 	IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    // }

    /********************** Pool State Changers ***********************/

    function _updateEmissions() internal {
        if (totalAllocPoint > 0 && block.timestamp > endRewardTime()) {
            _massUpdatePools();
            lastRPS = rewardsPerSecond;
            rewardsPerSecond = 0;
            return;
        }
        setScheduledRewardsPerSecond();
    }

    // Update reward variables for all pools
    function _massUpdatePools() internal {
        uint256 totalAP = totalAllocPoint;
        for (uint256 i = 0; i < poolLength(); ++i) {
            _updatePool(poolInfo[registeredTokens[i]], totalAP);
        }
        lastAllPoolUpdate = block.timestamp;
    }

    // Update reward variables of the given pool to be up-to-date.
    function _updatePool(PoolInfo storage pool, uint256 _totalAllocPoint) internal {
        uint256 timestamp = block.timestamp;
        if (endRewardTime() <= block.timestamp) {
            timestamp = endRewardTime();
        }
        if (timestamp <= pool.lastRewardTime) {
            return;
        }

        uint256 lpSupply = pool.totalSupply;
        if (lpSupply == 0) {
            pool.lastRewardTime = timestamp;
            return;
        }

        uint256 duration = timestamp.sub(pool.lastRewardTime);
        uint256 rawReward = duration.mul(rewardsPerSecond);

        if (availableRewards() < rawReward) {
            rawReward = availableRewards();
        }

        uint256 reward = rawReward.mul(pool.allocPoint).div(_totalAllocPoint);

        accountedRewards = accountedRewards.add(reward);
        pool.accRewardPerShare = pool.accRewardPerShare.add(
            reward.mul(ACC_REWARD_PRECISION).div(lpSupply)
        );
        pool.lastRewardTime = timestamp;
    }

    /********************** Emission Calc + Transfer ***********************/

    function pendingRewards(
        address _user,
        address[] memory _tokens
    ) public view returns (uint256[] memory) {
        uint256[] memory claimable = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            PoolInfo storage pool = poolInfo[token];
            UserInfo storage user = userInfo[token][_user];
            uint256 accRewardPerShare = pool.accRewardPerShare;
            uint256 lpSupply = pool.totalSupply;
            if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
                uint256 duration = block.timestamp.sub(pool.lastRewardTime);
                uint256 reward = duration.mul(rewardsPerSecond).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
                accRewardPerShare = accRewardPerShare.add(
                    reward.mul(ACC_REWARD_PRECISION).div(lpSupply)
                );
            }
            claimable[i] = user.amount.mul(accRewardPerShare).div(ACC_REWARD_PRECISION).sub(
                user.rewardDebt
            );
        }
        return claimable;
    }

    // Claim pending rewards for one or more pools.
    // Rewards are not received directly, they are minted by the rewardMinter.
    function claim(address _user, address[] memory _tokens) public {
        if (eligibilityEnabled) {
            checkAndProcessEligibility(_user, true, true);
        }

        _updateEmissions();

        uint256 pending = userBaseClaimable[_user];
        userBaseClaimable[_user] = 0;
        uint256 _totalAllocPoint = totalAllocPoint;
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(validRTokens[_tokens[i]], "invalid rtoken");
            PoolInfo storage pool = poolInfo[_tokens[i]];
            require(pool.lastRewardTime > 0, "pool doesn't exist");
            _updatePool(pool, _totalAllocPoint);
            UserInfo storage user = userInfo[_tokens[i]][_user];
            uint256 rewardDebt = user.amount.mul(pool.accRewardPerShare).div(ACC_REWARD_PRECISION);
            pending = pending.add(rewardDebt.sub(user.rewardDebt));
            user.rewardDebt = rewardDebt;
            user.lastClaimTime = block.timestamp;
        }

        _mint(_user, pending);

        eligibleDataProvider.updatePrice();

        if (endRewardTime() < block.timestamp + 5 days) {
            _emitReserveLow();
        }
    }

    function _emitReserveLow() internal {
        address rdntToken = rewardMinter.getRdntTokenAddress();
        emit ChefReserveLow(IERC20(rdntToken).balanceOf(address(this)));
    }

    function _mint(address _user, uint256 _amount) internal {
        _amount = _sendRadiant(address(_getMfd()), _amount);
        _getMfd().mint(_user, _amount, true);
    }

    function setEligibilityExempt(address _contract, bool _value) public {
        //require(msg.sender == owner() || msg.sender == address(leverager), "!authorized");
        eligibilityExempt[_contract] = _value;
    }

    function setLeverager(ILeverager _leverager) external {
        leverager = _leverager;
    }

    /********************** Eligibility + Disqualification ***********************/

    /**
     * @notice `after` Hook for deposit and borrow update.
     * @dev important! eligible status can be updated here
     */
    function handleActionAfter(address _user, uint256 _balance, uint256 _totalSupply) external {
        require(validRTokens[msg.sender] || msg.sender == address(_getMfd()), "!rToken || mfd");

        if (
            _user == address(rewardMinter) ||
            _user == address(_getMfd()) ||
            eligibilityExempt[_user]
        ) {
            return;
        }
        if (eligibilityEnabled) {
            eligibleDataProvider.refresh(_user);
            if (eligibleDataProvider.lastEligibleStatus(_user)) {
				_handleActionAfterForToken(msg.sender, _user, _balance, _totalSupply);
            } else {
                checkAndProcessEligibility(_user, true, false);
            }
        } else {
            _handleActionAfterForToken(msg.sender, _user, _balance, _totalSupply);
        }
    }

    function _handleActionAfterForToken(
        address _token,
        address _user,
        uint256 _balance,
        uint256 _totalSupply
    ) internal {
        PoolInfo storage pool = poolInfo[_token];
        require(pool.lastRewardTime > 0, "pool doesn't exist");
        //_updateEmissions();
        _updatePool(pool, totalAllocPoint);        
		UserInfo storage user = userInfo[_token][_user];
        uint256 amount = user.amount;
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (amount != 0) {
            uint256 pending = amount.mul(accRewardPerShare).div(ACC_REWARD_PRECISION).sub(
                user.rewardDebt
            );
            if (pending != 0) {
                userBaseClaimable[_user] = userBaseClaimable[_user].add(pending);
            }
        }
        pool.totalSupply = pool.totalSupply.sub(user.amount);
        user.amount = _balance;
        user.rewardDebt = _balance.mul(accRewardPerShare).div(ACC_REWARD_PRECISION);
        pool.totalSupply = pool.totalSupply.add(_balance);
        if (pool.onwardIncentives != IOnwardIncentivesController(address(0))) {
            pool.onwardIncentives.handleAction(_token, _user, _balance, _totalSupply);
        }

        emit BalanceUpdated(_token, _user, _balance, _totalSupply);
    }

    /**
     * @notice `before` Hook for deposit and borrow update.
     */
    function handleActionBefore(address _user) external {}

    /**
     * @notice Hook for lock update.
     * @dev Called by the locking contracts before locking or unlocking happens
     */
    function beforeLockUpdate(address _user) external {}

    /**
     * @notice Hook for lock update.
     * @dev Called by the locking contracts after locking or unlocking happens
     */
    function afterLockUpdate(address _user) external {
        require(msg.sender == address(_getMfd()), "!MFD");
        if (eligibilityEnabled) {
            eligibleDataProvider.refresh(_user);
            if (eligibleDataProvider.lastEligibleStatus(_user)) {
                for (uint256 i = 0; i < poolLength(); i++) {
                    uint256 newBal = IERC20(registeredTokens[i]).balanceOf(_user);
                    uint256 registeredBal = userInfo[registeredTokens[i]][_user].amount;
                    if (newBal != 0 && newBal != registeredBal) {
                        _handleActionAfterForToken(
                            registeredTokens[i],
                            _user,
                            newBal,
                            poolInfo[registeredTokens[i]].totalSupply.add(newBal).sub(registeredBal)
                        );
                    }
                }
            } else {
                checkAndProcessEligibility(_user, true, false);
            }
        }
    }

    /********************** Eligibility + Disqualification ***********************/

    function hasEligibleDeposits(address _user) internal view returns (bool hasDeposits) {
        for (uint256 i = 0; i < poolLength(); i++) {
            UserInfo storage user = userInfo[registeredTokens[i]][_user];
            if (user.amount != 0) {
                hasDeposits = true;
                break;
            }
        }
    }

    function checkAndProcessEligibility(
        address _user,
        bool _execute,
        bool _refresh
    ) internal returns (bool issueBaseBounty) {
        bool isEligible;
        if (_refresh && _execute) {
            eligibleDataProvider.refresh(_user);
            isEligible = eligibleDataProvider.lastEligibleStatus(_user);
        } else {
            isEligible = eligibleDataProvider.isEligibleForRewards(_user);
        }
        bool hasEligDeposits = hasEligibleDeposits(_user);
        uint256 lastDqTime = eligibleDataProvider.getDqTime(_user);
        bool alreadyDqd = lastDqTime != 0;

        if (!isEligible && hasEligDeposits && !alreadyDqd) {
            issueBaseBounty = true;
        }
        if (_execute && issueBaseBounty) {
            stopEmissionsFor(_user);
            emit Disqualified(_user);
        }
    }

    function claimBounty(address _user, bool _execute) public returns (bool issueBaseBounty) {
        require(msg.sender == address(bountyManager), "bounty only");
        issueBaseBounty = checkAndProcessEligibility(_user, _execute, true);
    }

    function stopEmissionsFor(address _user) internal {
        require(eligibilityEnabled, "!EE");
        // lastEligibleStatus will be fresh from refresh before this call
        require(!eligibleDataProvider.lastEligibleStatus(_user), "user is still eligible");
        for (uint256 i = 0; i < poolLength(); ++i) {
            address token = registeredTokens[i];
            PoolInfo storage pool = poolInfo[token];
            UserInfo storage user = userInfo[token][_user];

            if (user.amount != 0) {
                _handleActionAfterForToken(token, _user, 0, pool.totalSupply.sub(user.amount));
            }
        }
        eligibleDataProvider.setDqTime(_user, block.timestamp);
    }

    function _sendRadiant(address _user, uint256 _amount) internal returns (uint256) {
        if (_amount == 0) {
            return 0;
        }

        address rdntToken = rewardMinter.getRdntTokenAddress();
        uint256 chefReserve = IERC20(rdntToken).balanceOf(address(this));
        if (_amount > chefReserve) {
            emit ChefReserveEmpty(chefReserve);
            // RPS is set to zero
            // Set to persist to prevent update by _updateEmissions()
            persistRewardsPerSecond = true;
            rewardsPerSecond = 0;
        } else {
            IERC20(rdntToken).safeTransfer(_user, _amount);
        }
        return _amount;
    }

    /********************** RDNT Reserve Management ***********************/

    function endRewardTime() public returns (uint256) {
        if (endingTime.lastUpdatedTime + endingTime.updateCadence >= block.timestamp) {
            return endingTime.estimatedTime;
        }

        uint256 unclaimedRewards = depositedRewards.sub(accountedRewards);
        uint256 extra = 0;
        for (uint256 i; i < poolLength(); i++) {
            if (poolInfo[registeredTokens[i]].lastRewardTime <= lastAllPoolUpdate) {
                continue;
            } else {
                extra = extra.add(
                    poolInfo[registeredTokens[i]]
                        .lastRewardTime
                        .sub(lastAllPoolUpdate)
                        .mul(poolInfo[registeredTokens[i]].allocPoint)
                        .mul(rewardsPerSecond)
                        .div(totalAllocPoint)
                );
            }
        }
        if (rewardsPerSecond == 0) {
            endingTime.estimatedTime = type(uint256).max;
        } else {
            endingTime.estimatedTime =
                (unclaimedRewards + extra).div(rewardsPerSecond) +
                (lastAllPoolUpdate);
        }
        endingTime.lastUpdatedTime = block.timestamp;
        return endingTime.estimatedTime;
    }

    function setEndingTimeUpdateCadence(uint256 _lapse) external {
        require(_lapse <= 1 weeks, "cadence too long");
        endingTime.updateCadence = _lapse;
    }

    function registerRewardDeposit(uint256 _amount) external {
        depositedRewards = depositedRewards.add(_amount);
        _massUpdatePools();
        if (rewardsPerSecond == 0 && lastRPS > 0) {
            rewardsPerSecond = lastRPS;
        }
    }

    function availableRewards() internal view returns (uint256 amount) {
        return depositedRewards.sub(accountedRewards);
    }

    function claimAll(address _user) external {
        claim(_user, registeredTokens);
    }

    function allPendingRewards(address _user) public view returns (uint256 pending) {
        pending = userBaseClaimable[_user];
        uint256[] memory claimable = pendingRewards(_user, registeredTokens);
        for (uint256 i = 0; i < claimable.length; i++) {
            pending += claimable[i];
        }
    }
}
