// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "../helpers/OwnableUpgradeable.sol";
import "../interfaces/IStakingLP.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title StakingLP for the Pool Token
 * @notice Staking mechanism and rewards calculation
 */
contract StakingLP is
    IStakingLP,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public lpStakingToken;
    IERC20Upgradeable public rewardToken;

    /**
   * @dev A struct containing the stakeholder details
   * @member userRewardPerTokenPaid The rewardPerTokenStored when the user interacts with this contract
   * @member lpRewards The rewards of the user
   * @member userLpBalance The staked amount of the user
   * @member exist A boolean to show the user address exists or not
   */
    struct LPStakeholder {
        uint256 userRewardPerTokenPaid;
        uint256 lpRewards;
        uint256 userLpBalance;
        bool exist;
    }

    mapping(address => bool) public eligibleUsers;
    mapping(address => LPStakeholder) public lpStakeholders;
    address[] private addresses;
    address public opportunityContract;
    /**
    * @dev The start time of the opportunity
    */
    uint128 public startTime;
    uint128 public periodFinish;
    /**
    * @dev The last time this contract was called
    */
    uint128 public lastUpdatedTime;
    uint128 public rewardsDuration;
    /**
    * @dev Rewards minted per second
    */
    uint256 public rewardRate;
    /**
    * @dev The total number of LP token staked
    */
    uint256 private _totalSupply;
    /**
    * @dev The summation of rewardRate divided by the totalSupply at each given time
    */
    uint256 public rewardPerTokenStored;
    uint256 private _rewards;
    address public resonateAdapter;

    /* ========== EVENTS ========== */
    event LPStaked(address indexed user, uint256 amount);
    event WithdrawnRewards(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 lPBalance, uint256 rewardsBalance);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 oldDuration, uint256 newDuration);
    event callerSet(address caller);
    event StartTime(uint128 oldStartTime, uint128 newStartTime);
    event AddToEligibleUsers(address indexed user);
     
    /**
    * @dev The contract constructor
    * @param _lpStakingToken The address of the LP token
    * @param _rewardToken The address of the reward token
    * @param _rewardsDuration The duration that rewards are calculated
    * @param _startTime The start time of the opportunity
    */
    function initialize(
        address _lpStakingToken,
        address _rewardToken,
        uint128 _rewardsDuration,
        uint128 _startTime
    ) public initializer {
        OwnableUpgradeable.initialize();
        PausableUpgradeable.__Pausable_init();
        lpStakingToken = IERC20Upgradeable(_lpStakingToken);
        rewardToken = IERC20Upgradeable(_rewardToken);
        periodFinish = 0;
        rewardsDuration = _rewardsDuration;
        startTime = _startTime;
    }

    /* ========== MODIFIERS ========== */
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdatedTime =
            startTime >= lastTimeRewardApplicable() ? startTime : lastTimeRewardApplicable();
        if (_account != address(0)) {
            lpStakeholders[_account].lpRewards = earned(_account);
            lpStakeholders[_account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    /**
     * @param _amount The amount of the LP token to be staked
     * @param _account The address of the user
     */
    function stakeLP(
        uint256 _amount,
        address _account
    ) external nonReentrant updateReward(_account) {
        require(opportunityContract != address(0) && resonateAdapter != address(0),
            "LPStaking: address is not valid");
        require(msg.sender == opportunityContract || msg.sender == resonateAdapter,
            "LPStaking: caller is not verified");
        require(_amount > 0, "LPStaking: cannot stake 0");
        if (startTime > block.timestamp) {
            require(eligibleUsers[_account],
                "LPStaking: only eligible users are able to stake before start time");
        }
        if (!lpStakeholders[_account].exist) {
            lpStakeholders[_account].exist = true;
            addresses.push(_account);
        }
        lpStakeholders[_account].userLpBalance += _amount;
        lpStakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        _totalSupply += _amount;
        emit LPStaked(_account, _amount);
    }

    /**
     * @param _lpRewards The amount of the reward token to be withdrawn
     * @param _receiverAccount The address to which the rewards are to be transferred
     * @return The withdrawn amount of rewards
     */
    function withdrawRewards(
        uint256 _lpRewards,
        address _receiverAccount
    ) external nonReentrant whenNotPaused updateReward(msg.sender) returns (uint256) {
        require(_lpRewards > 0, "LPStaking: cannot withdraw 0");
        require(lpStakeholders[msg.sender].exist, "LPStaking: lpStakeholder does not exist");

        uint256 currentLPRewards = lpStakeholders[msg.sender].lpRewards;
        require(currentLPRewards >= _lpRewards, "LPStaking: not enough balance");
        rewardToken.safeTransfer(_receiverAccount, _lpRewards);
        lpStakeholders[msg.sender].lpRewards -= _lpRewards;

        emit WithdrawnRewards(msg.sender, _lpRewards);
        return _lpRewards;
    }

    /**
     * @notice If _lpAmount is equal to the staked balance, the user will receive rewards too
     * @param _lpAmount The amount of the LP tokens to be withdrawn
     * @param _originAccount The address to which the LP tokens are to be transferred
     * @return The withdrawn amount of LP tokens
     * @return The withdrawn amount of rewards
     */
    function withdraw(
        uint256 _lpAmount,
        address _originAccount
    ) external nonReentrant updateReward(_originAccount) returns (uint256, uint256) {
        address _resonateAdapter = resonateAdapter; // gas saving
        require(opportunityContract != address(0) && _resonateAdapter != address(0),
            "LPStaking: address is not valid");
        require(msg.sender == opportunityContract || msg.sender == _resonateAdapter,
            "LPStaking: caller is not verified");
        if (msg.sender == _resonateAdapter) {
            require(_originAccount == _resonateAdapter, "LPStaking: _originAccount is not valid");
        }
        require(_lpAmount > 0, "LPStaking: cannot withdraw 0");
        require(lpStakeholders[_originAccount].exist, "LPStaking: lpStakeholder does not exist");

        uint256 currentLPBalance = lpStakeholders[_originAccount].userLpBalance;
        require(currentLPBalance >= _lpAmount, "LPStaking: not enough balance");

        uint256 currentLPRewards;
        if (currentLPBalance == _lpAmount) {
            currentLPRewards = lpStakeholders[_originAccount].lpRewards;
            rewardToken.safeTransfer(msg.sender, currentLPRewards);
            delete lpStakeholders[_originAccount];
            uint256 index;
            for (uint256 i = 0; i < addresses.length; i++) {
                address lpStakeHolderAddress = addresses[i];
                if (lpStakeHolderAddress == _originAccount) {
                    index = i;
                    break;
                }
            }
            addresses[index] = addresses[addresses.length - 1];
            addresses.pop();
        } else {
            lpStakeholders[_originAccount].userLpBalance -= _lpAmount;
        }
        lpStakingToken.safeTransfer(msg.sender, _lpAmount);
        _totalSupply -= _lpAmount;
        emit Withdrawn(_originAccount, _lpAmount, currentLPRewards);
        return (_lpAmount, currentLPRewards);
    }

    /**
     * @notice If _lpAmount is equal to the staked balance, the user will receive rewards too
     * @param _lpAmount The amount of the LP tokens to be withdrawn
     * @param _originAccount The address to which the LP tokens are to be transferred
     * @return The withdrawn amount of LP tokens
     * @return The withdrawn amount of rewards
     */
    function withdrawByOwner(
        uint256 _lpAmount,
        address _originAccount
    ) external onlyOwner nonReentrant updateReward(_originAccount) returns (uint256, uint256) {
        require(_lpAmount > 0, "LPStaking: cannot withdraw 0");
        require(lpStakeholders[_originAccount].exist, "LPStaking: lpStakeholder does not exist");

        uint256 currentLPBalance = lpStakeholders[_originAccount].userLpBalance;
        require(currentLPBalance >= _lpAmount, "LPStaking: not enough balance");

        uint256 currentLPRewards;
        if (currentLPBalance == _lpAmount) {
            currentLPRewards = lpStakeholders[_originAccount].lpRewards;
            rewardToken.safeTransfer(_originAccount, currentLPRewards);
            delete lpStakeholders[_originAccount];
            uint256 index;
            for (uint256 i = 0; i < addresses.length; i++) {
                address lpStakeHolderAddress = addresses[i];
                if (lpStakeHolderAddress == _originAccount) {
                    index = i;
                    break;
                }
            }
            addresses[index] = addresses[addresses.length - 1];
            addresses.pop();
        } else {
            lpStakeholders[_originAccount].userLpBalance -= _lpAmount;
        }
        lpStakingToken.safeTransfer(_originAccount, _lpAmount);
        _totalSupply -= _lpAmount;
        emit Withdrawn(_originAccount, _lpAmount, currentLPRewards);
        return (_lpAmount, currentLPRewards);
    }

    /**
     * @notice The amount of reward token to be set for first time and to be added for next times
     * @param reward The amount of reward token to be added
     */
    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / rewardsDuration;
            _rewards = reward;
        } else {
            uint128 currentTime =
                startTime >= block.timestamp ? startTime : uint128(block.timestamp);
            uint128 remaining = periodFinish - currentTime;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / rewardsDuration;
            _rewards = reward + leftover;
        }
        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardToken.balanceOf(address(this));
        require(rewardRate <= balance / rewardsDuration, "LPStaking: Provided reward too high");
        lastUpdatedTime = startTime >= block.timestamp ? startTime : uint128(block.timestamp);
        periodFinish = startTime + rewardsDuration;
        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint128 _rewardsDuration) external onlyOwner {
        if (addresses.length > 0 && block.timestamp < periodFinish) {
            for (uint256 i = 0; i < addresses.length; i++) {
                address stakeHolderAddress = addresses[i];
                lpStakeholders[stakeHolderAddress].lpRewards = earned(stakeHolderAddress);
                lpStakeholders[stakeHolderAddress].userRewardPerTokenPaid = rewardPerTokenStored;
            }
        }

        uint256 oldDuration = rewardsDuration;
        rewardsDuration = _rewardsDuration;

        uint128 _startTime = startTime; //gas saving
        if (_startTime >= block.timestamp) {
            lastUpdatedTime = _startTime;
            rewardRate = _rewards / _rewardsDuration;
        } else {
            require(_startTime + _rewardsDuration > block.timestamp,
                "LPStaking: The new interval must be greater than the passed time of the previous interval");
            uint256 oldRemainingTime = periodFinish - block.timestamp;
            lastUpdatedTime = uint128(block.timestamp);
            rewardRate =
                oldRemainingTime * rewardRate / (_rewardsDuration + _startTime - block.timestamp);
        }
        periodFinish = _startTime + _rewardsDuration;
        emit RewardsDurationUpdated(oldDuration, _rewardsDuration);
    }

    function setOpportunityContract(address _opportunityContract) external onlyOwner {
        opportunityContract = _opportunityContract;
        emit callerSet(_opportunityContract);
    }

    function setResonateAdapter(address _resonateAdapter) external onlyOwner {
        resonateAdapter = _resonateAdapter;
        emit callerSet(_resonateAdapter);
    }

    function setStartTime(uint128 _startTime) external onlyOwner {
        require(_startTime > block.timestamp,
            "LPStaking: entered time must be greater than timestamp");
        require(block.timestamp < startTime, "LPStaking: changing start time is impossible");
        uint128 oldStartTime = startTime;
        startTime = _startTime;
        lastUpdatedTime = _startTime;
        periodFinish = _startTime + rewardsDuration;
        emit StartTime(oldStartTime, _startTime);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToEligibleUsers(address _account) external onlyOwner {
        require(!eligibleUsers[_account], "LPStaking: This account is available now");
        eligibleUsers[_account] = true;
        emit AddToEligibleUsers(_account);
    }

    function balanceOf(address _account) external view returns (uint256) {
        return lpStakeholders[_account].userLpBalance;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration;
    }

    function lastTimeRewardApplicable() public view returns (uint128) {
        return block.timestamp < periodFinish ? uint128(block.timestamp) : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0 || (lastTimeRewardApplicable() < lastUpdatedTime)) {
            return 0;
        }
        return
            rewardPerTokenStored +
                (rewardRate *
                    (lastTimeRewardApplicable() - lastUpdatedTime) * 1e18 / _totalSupply);
    }

    /**
     * @param _account The address of the user
     * @return The amount of rewards so far
     */
    function earned(address _account) public view returns (uint256) {
        return
            (lpStakeholders[_account].userLpBalance *
                (rewardPerToken() - lpStakeholders[_account].userRewardPerTokenPaid) / 1e18) +
                    lpStakeholders[_account].lpRewards;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

}
