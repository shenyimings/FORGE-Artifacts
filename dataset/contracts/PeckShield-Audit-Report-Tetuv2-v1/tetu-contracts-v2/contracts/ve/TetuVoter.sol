// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/ReentrancyGuard.sol";
import "../openzeppelin/EnumerableSet.sol";
import "../interfaces/IVeTetu.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IGauge.sol";
import "../interfaces/IBribe.sol";
import "../interfaces/IMultiPool.sol";
import "../proxy/ControllableV3.sol";

/// @title Voter for veTETU.
///        Based on Solidly contract.
/// @author belbix
contract TetuVoter is ReentrancyGuard, ControllableV3, IVoter {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant VOTER_VERSION = "1.0.0";
  /// @dev Rewards are released over 7 days
  uint internal constant _DURATION = 7 days;
  /// @dev Maximum votes per veNFT
  uint public constant MAX_VOTES = 10;
  /// @dev Delay between votes. We need delay for properly bribes distribution between votes.
  uint public constant VOTE_DELAY = 1 weeks;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev The ve token that governs these contracts
  address public override ve;
  address public token;
  address public gauge;
  address public bribe;

  // --- VOTES

  /// @dev veID => Last vote timestamp
  mapping(uint => uint) public lastVote;
  /// @dev Total voting weight
  uint public totalWeight;
  /// @dev vault => weight
  mapping(address => int256) public weights;
  /// @dev nft => vault => votes
  mapping(uint => mapping(address => int256)) public votes;
  /// @dev nft => vaults addresses voted for
  mapping(uint => address[]) public vaultsVotes;
  /// @dev nft => total voting weight of user
  mapping(uint => uint) public usedWeights;

  // --- ATTACHMENTS

  /// @dev veId => Attached staking token
  mapping(uint => EnumerableSet.AddressSet) internal _attachedStakingTokens;

  // --- REWARDS

  /// @dev Global index for accumulated distro
  uint public index;
  /// @dev vault => Saved global index for accumulated distro
  mapping(address => uint) public supplyIndex;
  /// @dev vault => Available to distribute reward amount
  mapping(address => uint) public claimable;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event Voted(address indexed voter, uint tokenId, int256 weight, address vault, int256 userWeight, int256 vePower);
  event Abstained(uint tokenId, int256 weight, address vault);
  event NotifyReward(address indexed sender, uint amount);
  event DistributeReward(address indexed sender, address indexed vault, uint amount);
  event Attach(address indexed owner, address indexed sender, address indexed stakingToken, uint tokenId);
  event Detach(address indexed owner, address indexed sender, address indexed stakingToken, uint tokenId);

  // *************************************************************
  //                        INIT
  // *************************************************************

  function init(
    address _controller,
    address _ve,
    address _rewardToken,
    address _gauge,
    address _bribe
  ) external initializer {
    __Controllable_init(_controller);

    _requireInterface(_ve, InterfaceIds.I_VE_TETU);
    _requireERC20(_rewardToken);
    _requireInterface(_gauge, InterfaceIds.I_GAUGE);
    _requireInterface(_bribe, InterfaceIds.I_BRIBE);

    ve = _ve;
    token = _rewardToken;
    gauge = _gauge;
    bribe = _bribe;

    // if the gauge will be changed in a new implementation, need to revoke approval and set a new
    IERC20(_rewardToken).safeApprove(gauge, type(uint).max);
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Returns true for valid vault registered in controller.
  function isVault(address _vault) public view returns (bool) {
    return IController(controller()).isValidVault(_vault);
  }

  /// @dev Returns register in controller vault by id .
  function validVaults(uint id) public view returns (address) {
    return IController(controller()).vaults(id);
  }

  /// @dev Valid vaults registered in controller length.
  function validVaultsLength() public view returns (uint) {
    return IController(controller()).vaultsListLength();
  }

  /// @dev Returns all attached addresses to given veId. Attachments suppose to be gauges.
  function attachedStakingTokens(uint veId) external view returns (address[] memory) {
    return _attachedStakingTokens[veId].values();
  }

  /// @dev Return voted vaults length for given veId.
  function votedVaultsLength(uint veId) external view returns (uint) {
    return vaultsVotes[veId].length;
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_VOTER || super.supportsInterface(interfaceId);
  }

  // *************************************************************
  //                        VOTES
  // *************************************************************

  /// @dev Resubmit exist votes for given token.
  ///      Need to call it for ve that did not renew votes too long.
  function poke(uint _tokenId) external {
    address[] memory _vaultVotes = vaultsVotes[_tokenId];
    uint length = _vaultVotes.length;
    int256[] memory _weights = new int256[](length);

    for (uint i; i < length; i++) {
      _weights[i] = votes[_tokenId][_vaultVotes[i]];
    }

    _vote(_tokenId, _vaultVotes, _weights);
  }

  /// @dev Remove all votes for given tokenId.
  ///      Ve token should be able to remove votes on transfer/withdraw
  function reset(uint tokenId) external {
    require(IVeTetu(ve).isApprovedOrOwner(msg.sender, tokenId) || msg.sender == ve, "!owner");
    require(lastVote[tokenId] + VOTE_DELAY < block.timestamp, "delay");
    _reset(tokenId);
  }

  /// @dev Vote for given pools using a vote power of given tokenId. Reset previous votes.
  function vote(uint tokenId, address[] calldata _vaultVotes, int256[] calldata _weights) external {
    require(IVeTetu(ve).isApprovedOrOwner(msg.sender, tokenId), "!owner");
    require(lastVote[tokenId] + VOTE_DELAY < block.timestamp, "delay");
    require(_vaultVotes.length == _weights.length, "!arrays");
    _vote(tokenId, _vaultVotes, _weights);
    lastVote[tokenId] = block.timestamp;
  }

  function _vote(uint _tokenId, address[] memory _vaultVotes, int256[] memory _weights) internal {
    _reset(_tokenId);
    uint length = _vaultVotes.length;

    require(length <= MAX_VOTES, "Too many votes");

    int256 _weight = int256(IVeTetu(ve).balanceOfNFT(_tokenId));
    int256 _totalVoteWeight = 0;
    int256 _totalWeight = 0;
    int256 _usedWeight = 0;

    for (uint i = 0; i < length; i++) {
      _totalVoteWeight += _weights[i] > 0 ? _weights[i] : - _weights[i];
    }

    for (uint i = 0; i < length; i++) {
      address _vault = _vaultVotes[i];
      require(isVault(_vault), "Invalid vault");

      int256 _vaultWeight = _weights[i] * _weight / _totalVoteWeight;
      require(votes[_tokenId][_vault] == 0, "duplicate vault");
      require(_vaultWeight != 0, "zero power");
      _updateFor(_vault);

      vaultsVotes[_tokenId].push(_vault);

      weights[_vault] += _vaultWeight;
      votes[_tokenId][_vault] += _vaultWeight;
      if (_vaultWeight > 0) {
        IBribe(bribe).deposit(_vault, uint(_vaultWeight), _tokenId);
      } else {
        _vaultWeight = - _vaultWeight;
      }
      _usedWeight += _vaultWeight;
      _totalWeight += _vaultWeight;
      emit Voted(msg.sender, _tokenId, _vaultWeight, _vault, _weights[i], _weight);
    }
    if (_usedWeight > 0) {
      IVeTetu(ve).voting(_tokenId);
    }
    totalWeight += uint(_totalWeight);
    usedWeights[_tokenId] = uint(_usedWeight);
  }

  /// @dev Remove all votes for given veId
  function _reset(uint _tokenId) internal {
    address[] storage _vaultsVotes = vaultsVotes[_tokenId];
    uint length = _vaultsVotes.length;
    int256 _totalWeight = 0;

    for (uint i = 0; i < length; i ++) {
      address _vault = _vaultsVotes[i];
      int256 _votes = votes[_tokenId][_vault];
      _updateFor(_vault);
      weights[_vault] -= _votes;
      votes[_tokenId][_vault] = 0;
      if (_votes > 0) {
        IBribe(bribe).withdraw(_vault, uint(_votes), _tokenId);
        _totalWeight += _votes;
      } else {
        _totalWeight -= _votes;
      }
      emit Abstained(_tokenId, _votes, _vault);
    }
    totalWeight -= uint(_totalWeight);
    usedWeights[_tokenId] = 0;
    delete vaultsVotes[_tokenId];
    if (_totalWeight > 0) {
      IVeTetu(ve).abstain(_tokenId);
    }
  }

  // *************************************************************
  //                        ATTACH/DETACH
  // *************************************************************

  /// @dev A gauge should be able to attach a token for preventing transfers/withdraws.
  function attachTokenToGauge(address stakingToken, uint tokenId, address account) external override {
    require(gauge == msg.sender, "!gauge");
    IVeTetu(ve).attachToken(tokenId);
    // no need to check the result - the gauge should send only new values
    _attachedStakingTokens[tokenId].add(stakingToken);
    emit Attach(account, msg.sender, stakingToken, tokenId);
  }

  /// @dev Detach given token.
  function detachTokenFromGauge(address stakingToken, uint tokenId, address account) external override {
    require(gauge == msg.sender, "!gauge");
    IVeTetu(ve).detachToken(tokenId);
    // no need to check the result - the gauge should send only exist values
    _attachedStakingTokens[tokenId].remove(stakingToken);
    emit Detach(account, msg.sender, stakingToken, tokenId);
  }

  /// @dev Detach given token from all gauges and votes
  ///      It could be pretty expensive call.
  ///      Need to have restrictions for max attached tokens and votes.
  function detachTokenFromAll(uint tokenId, address account) external override {
    require(msg.sender == ve, "!ve");

    _reset(tokenId);

    // need to copy addresses to memory, we will change this collection in the loop
    address[] memory tokens = _attachedStakingTokens[tokenId].values();
    uint length = tokens.length;
    for (uint i; i < length; ++i) {
      // no need to check attachments if _attachedStakingTokens properly updated
      IGauge(gauge).detachVe(tokens[i], account, tokenId);
    }
  }

  // *************************************************************
  //                    UPDATE INDEXES
  // *************************************************************

  /// @dev Update given vaults.
  function updateFor(address[] memory _vaults) external {
    for (uint i = 0; i < _vaults.length; i++) {
      _updateFor(_vaults[i]);
    }
  }

  /// @dev Update vaults by indexes in a range.
  function updateForRange(uint start, uint end) public {
    IController c = IController(controller());
    for (uint i = start; i < end; i++) {
      _updateFor(c.vaults(i));
    }
  }

  /// @dev Update all gauges.
  function updateAll() external {
    updateForRange(0, validVaultsLength());
  }

  function _updateFor(address _vault) internal {
    int256 _supplied = weights[_vault];
    if (_supplied > 0) {
      uint _supplyIndex = supplyIndex[_vault];
      // get global index for accumulated distro
      uint _index = index;
      // update vault current position to global position
      supplyIndex[_vault] = _index;
      // see if there is any difference that need to be accrued
      uint _delta = _index - _supplyIndex;
      if (_delta > 0) {
        // add accrued difference for each supplied token
        uint _share = uint(_supplied) * _delta / 1e18;
        claimable[_vault] += _share;
      }
    } else {
      // new users are set to the default global state
      supplyIndex[_vault] = index;
    }
  }

  // *************************************************************
  //                        REWARDS
  // *************************************************************

  /// @dev Add rewards to this contract. It will be distributed to gauges.
  function notifyRewardAmount(uint amount) external override {
    require(amount != 0, "zero amount");
    uint _totalWeight = totalWeight;
    // without votes rewards can not be added
    require(_totalWeight != 0, "!weights");
    // transfer the distro in
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    // 1e18 adjustment is removed during claim
    uint _ratio = amount * 1e18 / _totalWeight;
    if (_ratio > 0) {
      index += _ratio;
    }
    emit NotifyReward(msg.sender, amount);
  }

  /// @dev Notify rewards for given vault. Anyone can call
  function distribute(address _vault) external override {
    _distribute(_vault);
  }

  /// @dev Distribute rewards to all valid vaults.
  function distributeAll() external {
    uint length = validVaultsLength();
    IController c = IController(controller());
    for (uint x; x < length; x++) {
      _distribute(c.vaults(x));
    }
  }

  function distributeFor(uint start, uint finish) external {
    IController c = IController(controller());
    for (uint x = start; x < finish; x++) {
      _distribute(c.vaults(x));
    }
  }

  function _distribute(address _vault) internal nonReentrant {
    _updateFor(_vault);
    uint _claimable = claimable[_vault];
    address _token = token;
    address _gauge = gauge;
    // rewards should not extend period infinity, only higher amount allowed
    if (_claimable > IMultiPool(_gauge).left(_vault, _token)
      && _claimable / _DURATION > 0) {
      claimable[_vault] = 0;
      IGauge(_gauge).notifyRewardAmount(_vault, _token, _claimable);
      emit DistributeReward(msg.sender, _vault, _claimable);
    }
  }
}
