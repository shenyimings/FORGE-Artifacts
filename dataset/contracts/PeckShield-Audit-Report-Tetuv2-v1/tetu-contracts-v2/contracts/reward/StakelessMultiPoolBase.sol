// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/Math.sol";
import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/ReentrancyGuard.sol";
import "../openzeppelin/Initializable.sol";
import "../tools/TetuERC165.sol";
import "../interfaces/IMultiPool.sol";
import "../interfaces/IERC20.sol";
import "../lib/InterfaceIds.sol";
import "../proxy/ControllableV3.sol";

/// @title Abstract stakeless pool for multiple rewards.
///        Universal pool for different purposes, cover the most popular use cases.
/// @author belbix
abstract contract StakelessMultiPoolBase is TetuERC165, ReentrancyGuard, IMultiPool, ControllableV3 {
  using SafeERC20 for IERC20;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant MULTI_POOL_VERSION = "1.0.0";
  /// @dev Precision for internal calculations
  uint internal constant _PRECISION = 10 ** 27;
  /// @dev Max reward tokens per 1 staking token
  uint internal constant _MAX_REWARD_TOKENS = 10;

  // *************************************************************
  //                        VARIABLES
  //              Keep names and ordering!
  //     Add only in the bottom and adjust __gap variable
  // *************************************************************

  /// @dev Rewards are released over this period
  uint public duration;
  /// @dev This token will be always allowed as reward
  address public defaultRewardToken;

  /// @dev Staking token => Supply adjusted on derived balance logic. Use for rewards boost.
  mapping(address => uint) public override derivedSupply;
  /// @dev Staking token => Account => Staking token virtual balance. Can be adjusted regarding rewards boost logic.
  mapping(address => mapping(address => uint)) public override derivedBalances;
  /// @dev Staking token => Account => User virtual balance of staking token.
  mapping(address => mapping(address => uint)) public override balanceOf;
  /// @dev Staking token => Total amount of attached staking tokens
  mapping(address => uint) public override totalSupply;

  /// @dev Staking token => Reward token => Reward rate with precision _PRECISION
  mapping(address => mapping(address => uint)) public rewardRate;
  /// @dev Staking token => Reward token => Reward finish period in timestamp.
  mapping(address => mapping(address => uint)) public periodFinish;
  /// @dev Staking token => Reward token => Last updated time for reward token for internal calculations.
  mapping(address => mapping(address => uint)) public lastUpdateTime;
  /// @dev Staking token => Reward token => Part of SNX pool logic. Internal snapshot of reward per token value.
  mapping(address => mapping(address => uint)) public rewardPerTokenStored;

  /// @dev Staking token => Reward token => Account => amount. Already paid reward amount for snapshot calculation.
  mapping(address => mapping(address => mapping(address => uint))) public userRewardPerTokenPaid;
  /// @dev Staking token => Reward token => Account => amount. Snapshot of user's reward per token.
  mapping(address => mapping(address => mapping(address => uint))) public rewards;

  /// @dev Allowed reward tokens for staking token
  mapping(address => address[]) public override rewardTokens;
  /// @dev Allowed reward tokens for staking token stored in map for fast check.
  mapping(address => mapping(address => bool)) public override isRewardToken;
  /// @notice account => recipient. All rewards for this account will receive recipient
  mapping(address => address) public rewardsRedirect;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event BalanceIncreased(address indexed token, address indexed account, uint amount);
  event BalanceDecreased(address indexed token, address indexed account, uint amount);
  event NotifyReward(address indexed from, address token, address indexed reward, uint amount);
  event ClaimRewards(address indexed account, address token, address indexed reward, uint amount, address recepient);

  // *************************************************************
  //                        INIT
  // *************************************************************

  function __MultiPool_init(
    address controller_,
    address _defaultRewardToken,
    uint _duration
  ) internal onlyInitializing {
    __Controllable_init(controller_);
    _requireERC20(_defaultRewardToken);
    defaultRewardToken = _defaultRewardToken;
    require(_duration != 0, "wrong duration");
    duration = _duration;
  }

  // *************************************************************
  //                        RESTRICTIONS
  // *************************************************************

  modifier onlyAllowedContracts() {
    IController _controller = IController(controller());
    require(
      msg.sender == _controller.governance()
      || msg.sender == _controller.forwarder()
    , "Not allowed");
    _;
  }

  // *************************************************************
  //                            VIEWS
  // *************************************************************

  /// @dev Should return true for whitelisted reward tokens
  function isStakeToken(address token) public view override virtual returns (bool);

  /// @dev Length of rewards tokens array for given token
  function rewardTokensLength(address token) external view override returns (uint) {
    return rewardTokens[token].length;
  }

  /// @dev Reward paid for token for the current period.
  function rewardPerToken(address stakingToken, address rewardToken) public view returns (uint) {
    uint _derivedSupply = derivedSupply[stakingToken];
    if (_derivedSupply == 0) {
      return rewardPerTokenStored[stakingToken][rewardToken];
    }

    return rewardPerTokenStored[stakingToken][rewardToken]
    +
    (lastTimeRewardApplicable(stakingToken, rewardToken) - lastUpdateTime[stakingToken][rewardToken])
    * rewardRate[stakingToken][rewardToken]
    / _derivedSupply;
  }

  /// @dev Returns the last time the reward was modified or periodFinish if the reward has ended
  function lastTimeRewardApplicable(address stakingToken, address rewardToken) public view returns (uint) {
    uint _periodFinish = periodFinish[stakingToken][rewardToken];
    return block.timestamp < _periodFinish ? block.timestamp : _periodFinish;
  }

  /// @dev Balance of holder adjusted with specific rules for boost calculation.
  ///      Supposed to be implemented in a parent contract
  ///      Adjust user balance with some logic, like boost logic.
  function derivedBalance(address stakingToken, address account) public view virtual override returns (uint) {
    return balanceOf[stakingToken][account];
  }

  /// @dev Amount of reward tokens left for the current period
  function left(address stakingToken, address rewardToken) public view override returns (uint) {
    uint _periodFinish = periodFinish[stakingToken][rewardToken];
    if (block.timestamp >= _periodFinish) return 0;
    uint _remaining = _periodFinish - block.timestamp;
    return _remaining * rewardRate[stakingToken][rewardToken] / _PRECISION;
  }

  /// @dev Approximate of earned rewards ready to claim
  function earned(address stakingToken, address rewardToken, address account) public view override returns (uint) {
    return derivedBalance(stakingToken, account)
    * (rewardPerToken(stakingToken, rewardToken) - userRewardPerTokenPaid[stakingToken][rewardToken][account])
    / _PRECISION
    + rewards[stakingToken][rewardToken][account];
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override(ControllableV3, TetuERC165) returns (bool) {
    return interfaceId == InterfaceIds.I_MULTI_POOL || super.supportsInterface(interfaceId);
  }

  // *************************************************************
  //                  OPERATOR ACTIONS
  // *************************************************************

  /// @dev Whitelist reward token for staking token. Only operator can do it.
  function registerRewardToken(address stakeToken, address rewardToken) external override onlyAllowedContracts {
    require(rewardTokens[stakeToken].length < _MAX_REWARD_TOKENS, "Too many reward tokens");
    require(!isRewardToken[stakeToken][rewardToken], "Already registered");
    isRewardToken[stakeToken][rewardToken] = true;
    rewardTokens[stakeToken].push(rewardToken);
  }

  /// @dev Remove from whitelist reward token for staking token. Only operator can do it.
  ///      We assume that the first token can not be removed.
  function removeRewardToken(address stakeToken, address rewardToken) external override onlyAllowedContracts {
    require(periodFinish[stakeToken][rewardToken] < block.timestamp, "Rewards not ended");
    require(isRewardToken[stakeToken][rewardToken], "Not reward token");

    isRewardToken[stakeToken][rewardToken] = false;
    uint length = rewardTokens[stakeToken].length;
    uint i = 0;
    for (; i < length; i++) {
      address t = rewardTokens[stakeToken][i];
      if (t == rewardToken) {
        break;
      }
    }
    // if isRewardToken map and rewardTokens array changed accordingly the token always exist
    rewardTokens[stakeToken][i] = rewardTokens[stakeToken][length - 1];
    rewardTokens[stakeToken].pop();
  }

  /// @dev Account or governance can setup a redirect of all rewards.
  ///      It needs for 3rd party contracts integrations.
  function setRewardsRedirect(address account, address recipient) external {
    require(msg.sender == account || isGovernance(msg.sender), "Not allowed");
    rewardsRedirect[account] = recipient;
  }

  // *************************************************************
  //                      BALANCE
  // *************************************************************

  /// @dev Assume to be called when linked token balance changes.
  function _registerBalanceIncreasing(
    address stakingToken,
    address account,
    uint amount
  ) internal virtual nonReentrant {
    require(isStakeToken(stakingToken), "Staking token not allowed");
    require(amount > 0, "Zero amount");

    _increaseBalance(stakingToken, account, amount);
    emit BalanceIncreased(stakingToken, account, amount);
  }

  function _increaseBalance(
    address stakingToken,
    address account,
    uint amount
  ) internal virtual {
    _updateRewardForAllTokens(stakingToken, account);
    totalSupply[stakingToken] += amount;
    balanceOf[stakingToken][account] += amount;
    _updateDerivedBalance(stakingToken, account);
  }

  /// @dev Assume to be called when linked token balance changes.
  function _registerBalanceDecreasing(
    address stakingToken,
    address account,
    uint amount
  ) internal nonReentrant virtual {
    require(isStakeToken(stakingToken), "Staking token not allowed");
    _decreaseBalance(stakingToken, account, amount);
    emit BalanceDecreased(stakingToken, account, amount);
  }

  function _decreaseBalance(
    address stakingToken,
    address account,
    uint amount
  ) internal virtual {
    _updateRewardForAllTokens(stakingToken, account);
    totalSupply[stakingToken] -= amount;
    balanceOf[stakingToken][account] -= amount;
    _updateDerivedBalance(stakingToken, account);
  }

  function _updateDerivedBalance(address stakingToken, address account) internal {
    uint __derivedBalance = derivedBalances[stakingToken][account];
    derivedSupply[stakingToken] -= __derivedBalance;
    __derivedBalance = derivedBalance(stakingToken, account);
    derivedBalances[stakingToken][account] = __derivedBalance;
    derivedSupply[stakingToken] += __derivedBalance;
  }

  // *************************************************************
  //                          CLAIM
  // *************************************************************

  /// @dev Caller should implement restriction checks
  function _getReward(
    address stakingToken,
    address account,
    address[] memory rewardTokens_,
    address recipient
  ) internal nonReentrant virtual {
    address newRecipient = rewardsRedirect[recipient];
    if (newRecipient != address(0)) {
      recipient = newRecipient;
    }
    require(recipient == msg.sender, "Not allowed");

    _updateDerivedBalance(stakingToken, account);

    for (uint i = 0; i < rewardTokens_.length; i++) {
      address rewardToken = rewardTokens_[i];
      _updateReward(stakingToken, rewardToken, account);

      uint _reward = rewards[stakingToken][rewardToken][account];
      if (_reward > 0) {
        rewards[stakingToken][rewardToken][account] = 0;
        IERC20(rewardToken).safeTransfer(recipient, _reward);
      }

      emit ClaimRewards(account, stakingToken, rewardToken, _reward, recipient);
    }
  }

  // *************************************************************
  //                    REWARDS CALCULATIONS
  // *************************************************************

  function _updateRewardForAllTokens(address stakingToken, address account) internal {
    address[] memory rts = rewardTokens[stakingToken];
    uint length = rts.length;
    for (uint i; i < length; i++) {
      _updateReward(stakingToken, rts[i], account);
    }
    _updateReward(stakingToken, defaultRewardToken, account);
  }

  function _updateReward(address stakingToken, address rewardToken, address account) internal {
    uint _rewardPerTokenStored = rewardPerToken(stakingToken, rewardToken);
    rewardPerTokenStored[stakingToken][rewardToken] = _rewardPerTokenStored;
    lastUpdateTime[stakingToken][rewardToken] = lastTimeRewardApplicable(stakingToken, rewardToken);
    if (account != address(0)) {
      rewards[stakingToken][rewardToken][account] = earned(stakingToken, rewardToken, account);
      userRewardPerTokenPaid[stakingToken][rewardToken][account] = _rewardPerTokenStored;
    }
  }

  // *************************************************************
  //                         NOTIFY
  // *************************************************************

  function _notifyRewardAmount(
    address stakingToken,
    address rewardToken,
    uint amount,
    bool transferRewards
  ) internal virtual {
    require(amount > 0, "Zero amount");
    require(defaultRewardToken == rewardToken || isRewardToken[stakingToken][rewardToken], "Token not allowed");

    _updateReward(stakingToken, rewardToken, address(0));
    uint _duration = duration;

    if (transferRewards) {
      uint balanceBefore = IERC20(rewardToken).balanceOf(address(this));
      IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
      // refresh amount if token was taxable
      amount = IERC20(rewardToken).balanceOf(address(this)) - balanceBefore;
    }
    // if transferRewards=false need to wisely use it in implementation!

    if (block.timestamp >= periodFinish[stakingToken][rewardToken]) {
      rewardRate[stakingToken][rewardToken] = amount * _PRECISION / _duration;
    } else {
      uint _remaining = periodFinish[stakingToken][rewardToken] - block.timestamp;
      uint _left = _remaining * rewardRate[stakingToken][rewardToken];
      // rewards should not extend period infinity, only higher amount allowed
      require(amount > _left / _PRECISION, "Amount should be higher than remaining rewards");
      rewardRate[stakingToken][rewardToken] = (amount * _PRECISION + _left) / _duration;
    }

    lastUpdateTime[stakingToken][rewardToken] = block.timestamp;
    periodFinish[stakingToken][rewardToken] = block.timestamp + _duration;
    emit NotifyReward(msg.sender, stakingToken, rewardToken, amount);
  }

  /**
* @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
  uint[38] private __gap;
}
