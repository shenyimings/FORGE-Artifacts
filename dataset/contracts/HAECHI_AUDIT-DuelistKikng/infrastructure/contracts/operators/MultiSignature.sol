// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Address.sol';
import '../libraries/Verifier.sol';
import '../libraries/Bytes.sol';
import '../libraries/Permissioned.sol';

/**
 * Orochi Multi Signature Wallet
 * Name: N/A
 * Domain: N/A
 */
contract MultiSignature is Permissioned {
  // Address lib providing safe {call} and {delegatecall}
  using Address for address;

  // Byte manipulation
  using Bytes for bytes;

  // Verifiy digital signature
  using Verifier for bytes;

  // Structure of proposal
  struct Proposal {
    int256 vote;
    uint256 expired;
    bool executed;
    uint256 value;
    address target;
    bytes data;
  }

  // Permission constants
  uint256 internal constant PERMISSION_CREATE = 1;
  uint256 internal constant PERMISSION_SIGN = 2;
  uint256 internal constant PERMISSION_VOTE = 4;
  uint256 internal constant PERMISSION_OBSERVER = 4294967296;

  // Proposal index, begin from 0
  uint256 private _totalProposal;

  // Proposal storage
  mapping(uint256 => Proposal) private _proposalStorage;

  // Voted storage
  mapping(uint256 => mapping(address => bool)) private _votedStorage;

  // Quick transaction nonce
  uint256 private _nonce = 0;

  // Total number of signer
  uint256 private _totalSigner = 0;

  // Threshold for a proposal to be passed, it' usual 50%
  int256 private _threshold;

  // Threshold for all participants to be drag a long, it's usual 70%
  int256 private _thresholdDrag;

  // Create a new proposal
  event NewProposal(address creator, uint256 indexed proposalId, uint256 indexed expired);

  // Execute proposal
  event ExecuteProposal(uint256 indexed proposalId, address indexed trigger, int256 indexed vote);

  // Positive vote
  event PositiveVote(uint256 indexed proposalId, address indexed owner);

  // Negative vote
  event NegativeVote(uint256 indexed proposalId, address indexed owner);

  // Receive payment
  event Transaction(address indexed from, address indexed to, uint256 indexed value);

  // This contract able to receive fund
  receive() external payable {
    if (msg.value > 0) emit Transaction(msg.sender, address(this), msg.value);
  }

  // Init method which can be called once
  function init(
    address[] memory users_,
    uint256[] memory roles_,
    int256 threshold_,
    int256 thresholdDrag_
  ) external {
    for (uint256 i = 0; i < users_.length; i += 1) {
      if (roles_[i] & PERMISSION_SIGN > 0) {
        _totalSigner += 1;
      }
    }
    // These values can be set once
    _threshold = threshold_;
    _thresholdDrag = thresholdDrag_;
    require(_init(users_, roles_) > 0, 'S: Unable to init contract');
  }

  /*******************************************************
   * User section
   ********************************************************/
  // Transfer role to new user
  function transferRole(address newUser) external onlyUser {
    // New user will be activated after 30 days
    // We prevent them to vote and transfer permission to the other
    _transferRole(newUser, 30 days);
  }

  /*******************************************************
   * Creator section
   ********************************************************/
  // Transfer with signed off-chain proofs instead of on-chain voting
  function quickTransfer(bytes[] memory signatures, bytes memory txData)
    external
    onlyAllow(PERMISSION_CREATE)
    returns (bool)
  {
    uint256 totalSigned = 0;
    address[] memory signedAddresses = new address[](signatures.length);
    for (uint256 i = 0; i < signatures.length; i += 1) {
      address signer = txData.verifySerialized(signatures[i]);
      // Each signer only able to be counted once
      if (isRole(signer, PERMISSION_SIGN) && _isNotInclude(signedAddresses, signer)) {
        signedAddresses[totalSigned] = signer;
        totalSigned += 1;
      }
    }
    require(_calculatePercent(int256(totalSigned)) >= _thresholdDrag, 'S: Total signed was not pass drag threshold');
    uint256 packagedNonce = txData.readUint256(0);
    address target = txData.readAddress(32);
    uint256 value = txData.readUint256(52);
    bytes memory data = txData.readBytes(84, txData.length - 84);
    uint256 nonce = packagedNonce & 0xffffffffffffffffffffffffffffffff;
    uint256 votingTime = packagedNonce >> 128;
    require(nonce - _nonce == 1, 'S: Invalid nonce value');
    require(votingTime > block.timestamp && votingTime < block.timestamp + 3 days, 'S: Timeout');
    _nonce = nonce;
    if (target.isContract()) {
      target.functionCallWithValue(data, value);
    } else {
      payable(address(target)).transfer(value);
    }
    return true;
  }

  // Create a new proposal
  function createProposal(
    address target_,
    uint256 value_,
    uint256 expired_,
    bytes memory data_
  ) external onlyAllow(PERMISSION_CREATE) returns (uint256) {
    // Minimum expire time is 1 day
    uint256 expired = expired_ > block.timestamp + 1 days ? expired_ : block.timestamp + 1 days;
    uint256 proposalIndex = _totalProposal;
    _proposalStorage[proposalIndex] = Proposal({
      target: target_,
      value: value_,
      data: data_,
      expired: expired,
      vote: 0,
      executed: false
    });
    emit NewProposal(msg.sender, proposalIndex, expired);
    _totalProposal = proposalIndex + 1;
    return proposalIndex;
  }

  /*******************************************************
   * Vote permission section
   ********************************************************/
  // Positive vote
  function votePositive(uint256 proposalId) external onlyAllow(PERMISSION_VOTE) returns (bool) {
    return _voteProposal(proposalId, true);
  }

  // Negative vote
  function voteNegative(uint256 proposalId) external onlyAllow(PERMISSION_VOTE) returns (bool) {
    return _voteProposal(proposalId, false);
  }

  /*******************************************************
   * Sign permission section
   ********************************************************/
  // Execute a voted proposal
  function execute(uint256 proposalId) external onlyAllow(PERMISSION_VOTE) returns (bool) {
    Proposal memory currentProposal = _proposalStorage[proposalId];
    int256 voting = _calculatePercent(currentProposal.vote);
    // If positiveVoted < 70%, It need to pass 50% and expired
    if (voting < int256(_thresholdDrag)) {
      require(block.timestamp > _proposalStorage[proposalId].expired, "S: Voting period wasn't over");
      require(voting >= 50, 'S: Vote was not pass 50%');
    }
    require(currentProposal.executed == false, 'S: Proposal was executed');

    if (currentProposal.target.isContract()) {
      currentProposal.target.functionCallWithValue(currentProposal.data, currentProposal.value);
    } else {
      payable(address(currentProposal.target)).transfer(currentProposal.value);
    }
    currentProposal.executed = true;
    _proposalStorage[proposalId] = currentProposal;
    emit ExecuteProposal(proposalId, msg.sender, currentProposal.vote);
    return true;
  }

  /*******************************************************
   * Private section
   ********************************************************/
  // Vote a proposal
  function _voteProposal(uint256 proposalId, bool positive) private returns (bool) {
    require(block.timestamp < _proposalStorage[proposalId].expired, 'MultiSig: Voting period was over');
    require(_votedStorage[proposalId][msg.sender] == false, 'MultiSig: You had voted this proposal');
    if (positive) {
      _proposalStorage[proposalId].vote += 1;
      emit PositiveVote(proposalId, msg.sender);
    } else {
      _proposalStorage[proposalId].vote -= 1;
      emit NegativeVote(proposalId, msg.sender);
    }
    _votedStorage[proposalId][msg.sender] = true;
    return true;
  }

  /*******************************************************
   * Pure section
   ********************************************************/

  function _isNotInclude(address[] memory addressList, address checkAddress) private pure returns (bool) {
    for (uint256 i = 0; i < addressList.length; i += 1) {
      if (addressList[i] == checkAddress) {
        return false;
      }
    }
    return true;
  }

  function _calculatePercent(int256 votedUsers) private view returns (int256) {
    return (votedUsers * 10000) / int256(_totalSigner * 100);
  }

  /*******************************************************
   * View section
   ********************************************************/

  function getPackedTransaction(
    address target,
    uint256 value,
    bytes memory data
  ) external view returns (bytes memory) {
    return abi.encodePacked(uint128(block.timestamp), uint128(_nonce + 1), target, value, data);
  }

  function getTotalProposal() external view returns (uint256) {
    return _totalProposal;
  }

  function proposalDetail(uint256 index) external view returns (Proposal memory) {
    return _proposalStorage[index];
  }

  function isVoted(uint256 proposalId, address owner) external view returns (bool) {
    return _votedStorage[proposalId][owner];
  }

  function getNextValidNonce() external view returns (uint256) {
    return _nonce + 1;
  }

  function getTotalSigner() external view returns (uint256) {
    return _totalSigner;
  }
}
