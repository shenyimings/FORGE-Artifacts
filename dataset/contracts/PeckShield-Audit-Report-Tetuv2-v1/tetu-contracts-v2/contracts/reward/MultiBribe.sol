// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IVoter.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IBribe.sol";
import "./StakelessMultiPoolBase.sol";
import "../interfaces/IForwarder.sol";

/// @title Stakeless pool for ve token
/// @author belbix
contract MultiBribe is StakelessMultiPoolBase, IBribe {
  using SafeERC20 for IERC20;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant MULTI_BRIBE_VERSION = "1.0.0";

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev The ve token used for gauges
  address public ve;
  /// @dev vault => rt => epoch => amount
  mapping(address => mapping(address => mapping(uint => uint))) public rewardsQueue;
  /// @dev Current epoch for delayed rewards
  uint public override epoch;
  address public epochOperator;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event BribeDeposit(address indexed vault, uint indexed veId, uint amount);
  event BribeWithdraw(address indexed vault, uint indexed veId, uint amount);
  event RewardsForNextEpoch(address vault, address token, uint epoch, uint amount);
  event DelayedRewardsNotified(address vault, address token, uint epoch, uint amount);
  event EpochOperatorChanged(address value);
  event EpochIncreased(uint epoch);

  // *************************************************************
  //                        INIT
  // *************************************************************

  function init(
    address controller_,
    address _ve,
    address _defaultReward
  ) external initializer {
    __MultiPool_init(controller_, _defaultReward, 1);
    _requireInterface(_ve, InterfaceIds.I_VE_TETU);
    ve = _ve;
  }

  function voter() public view returns (address) {
    return IController(controller()).voter();
  }

  // *************************************************************
  //                      GOV ACTIONS
  // *************************************************************

  function setEpochOperator(address value) external {
    require(isGovernance(msg.sender), "!gov");
    epochOperator = value;
    emit EpochOperatorChanged(value);
  }

  // *************************************************************
  //                        CLAIMS
  // *************************************************************

  function getReward(
    address _vault,
    uint veId,
    address[] memory tokens
  ) external override {
    _getReward(_vault, veId, tokens, IERC721(ve).ownerOf(veId));
  }

  function getAllRewards(
    address _vault,
    uint veId
  ) external override {
    _getAllRewards(_vault, veId, IERC721(ve).ownerOf(veId));
  }

  function _getAllRewards(
    address _vault,
    uint veId,
    address recipient
  ) internal {
    address[] storage rts = rewardTokens[_vault];
    uint length = rts.length;
    address[] memory tokens = new address[](length + 1);
    for (uint i; i < length; ++i) {
      tokens[i] = rts[i];
    }
    tokens[length] = defaultRewardToken;
    _getReward(_vault, veId, tokens, recipient);
  }

  function getAllRewardsForTokens(
    address[] memory _vaults,
    uint veId
  ) external override {
    address recipient = IERC721(ve).ownerOf(veId);
    for (uint i; i < _vaults.length; i++) {
      _getAllRewards(_vaults[i], veId, recipient);
    }
  }

  function _getReward(
    address _vault,
    uint veId,
    address[] memory _rewardTokens,
    address recipient
  ) internal {
    IForwarder(IController(controller()).forwarder()).distributeAll(_vault);
    uint _epoch = epoch;
    for (uint i; i < _rewardTokens.length; ++i) {
      _notifyDelayedRewards(_vault, _rewardTokens[i], _epoch);
    }
    _getReward(_vault, tokenIdToAddress(veId), _rewardTokens, recipient);
  }

  // *************************************************************
  //                   DEPOSIT/WITHDRAW
  // *************************************************************

  /// @dev Only voter can call it when a user vote for the vault
  function deposit(address vault, uint amount, uint veId) external override {
    require(msg.sender == voter(), "Not voter");
    _registerBalanceIncreasing(vault, tokenIdToAddress(veId), amount);
    emit BribeDeposit(vault, veId, amount);
  }

  /// @dev Only voter can call it when a user reset the vote for the vault.
  function withdraw(address vault, uint amount, uint veId) external override {
    require(msg.sender == voter(), "Not voter");
    _registerBalanceDecreasing(vault, tokenIdToAddress(veId), amount);
    emit BribeWithdraw(vault, veId, amount);
  }

  // *************************************************************
  //                   REWARDS DISTRIBUTION
  // *************************************************************

  /// @dev Add rewards to the current users
  function notifyRewardAmount(address vault, address token, uint amount) external nonReentrant override {
    _notifyRewardAmount(vault, token, amount, true);
  }

  /// @dev Add delayed rewards for the next epoch
  function notifyForNextEpoch(address vault, address token, uint amount) external nonReentrant override {
    require(defaultRewardToken == token || isRewardToken[vault][token], "Token not allowed");

    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    uint _epoch = epoch + 1;
    rewardsQueue[vault][token][_epoch] = amount;

    emit RewardsForNextEpoch(vault, token, _epoch, amount);
  }

  /// @dev Notify delayed rewards
  function notifyDelayedRewards(address vault, address token, uint _epoch) external nonReentrant override {
    require(epoch == _epoch, "!epoch");
    _notifyDelayedRewards(vault, token, _epoch);
  }

  function _notifyDelayedRewards(address vault, address token, uint _epoch) internal {
    uint amount = rewardsQueue[vault][token][_epoch];
    if (amount != 0 && amount > left(vault, token)) {
      _notifyRewardAmount(vault, token, amount, false);
      delete rewardsQueue[vault][token][_epoch];
      emit DelayedRewardsNotified(vault, token, epoch, amount);
    }
  }

  /// @dev Increase the current epoch by one, Epoch operator should increase it weekly.
  function increaseEpoch() external override {
    require(msg.sender == epochOperator, "!operator");
    epoch++;
    emit EpochIncreased(epoch);
  }

  // *************************************************************
  //                   INTERNAL LOGIC
  // *************************************************************

  function isStakeToken(address token) public view override returns (bool) {
    return IController(controller()).isValidVault(token);
  }

  function addressToTokenId(address adr) public pure returns (uint) {
    return uint(uint160(adr));
  }

  function tokenIdToAddress(uint tokenId) public pure returns (address) {
    address adr = address(uint160(tokenId));
    require(addressToTokenId(adr) == tokenId, "Wrong convert");
    return adr;
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override(StakelessMultiPoolBase) returns (bool) {
    return interfaceId == InterfaceIds.I_BRIBE || super.supportsInterface(interfaceId);
  }

}
