// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/utils/Address.sol';
import '../libraries/Verifier.sol';
import '../libraries/Bytes.sol';
import './MultiOwner.sol';

/**
 * Multi Signature Wallet
 * Name: N/A
 * Domain: N/A
 */
contract MultiSig is MultiOwner {
  // Address lib providing safe {call} and {delegatecall}
  using Address for address;

  // Byte manipulation
  using Bytes for bytes;

  // Verifiy digital signature
  using Verifier for bytes;

  // Structure of proposal
  struct Proposal {
    int256 vote;
    uint64 expired;
    bool executed;
    bool delegate;
    uint256 value;
    address target;
    bytes data;
  }

  // Proposal index, begin from 1
  uint256 private _proposalIndex;

  // Proposal storage
  mapping(uint256 => Proposal) private _proposalStorage;

  // Voted storage
  mapping(uint256 => mapping(address => bool)) private _votedStorage;

  // Quick transaction nonce
  uint256 private _nonce;

  // Create a new proposal
  event CreateProposal(uint256 indexed proposalId, uint256 indexed expired);

  // Execute proposal
  event ExecuteProposal(uint256 indexed proposalId, address indexed trigger, int256 indexed vote);

  // Positive vote
  event PositiveVote(uint256 indexed proposalId, address indexed owner);

  // Negative vote
  event NegativeVote(uint256 indexed proposalId, address indexed owner);

  // This contract able to receive fund
  receive() external payable {}

  // Pass parameters to parent contract
  constructor(address[] memory owners_) MultiOwner(owners_) {}

  /*******************************************************
   * Owner section
   ********************************************************/
  // Transfer ownership to new owner
  function transferOwnership(address newOwner) external onlyListedOwner {
    // New owner will be activated after 3 days
    _transferOwnership(newOwner, 3 days);
  }

  // Transfer with signed proofs instead of onchain voting
  function quickTransfer(bytes[] memory signatures, bytes memory txData) external onlyListedOwner returns (bool) {
    uint256 totalSigned = 0;
    address[] memory signedAddresses = new address[](signatures.length);
    for (uint256 i = 0; i < signatures.length; i += 1) {
      address signer = txData.verifySerialized(signatures[i]);
      // Each signer only able to be counted once
      if (isOwner(signer) && _isNotInclude(signedAddresses, signer)) {
        signedAddresses[totalSigned] = signer;
        totalSigned += 1;
      }
    }
    require(_calculatePercent(int256(totalSigned)) >= 70, 'MultiSig: Total signed was not greater than 70%');
    uint256 nonce = txData.readUint256(0);
    address target = txData.readAddress(32);
    bytes memory data = txData.readBytes(52, txData.length - 52);
    require(nonce - _nonce == 1, 'MultiSign: Invalid nonce value');
    _nonce = nonce;
    target.functionCallWithValue(data, 0);
    return true;
  }

  // Create a new proposal
  function createProposal(Proposal memory newProposal) external onlyListedOwner returns (uint256) {
    _proposalIndex += 1;
    newProposal.expired = uint64(block.timestamp + 1 days);
    newProposal.vote = 0;
    _proposalStorage[_proposalIndex] = newProposal;
    emit CreateProposal(_proposalIndex, newProposal.expired);
    return _proposalIndex;
  }

  // Positive vote
  function votePositive(uint256 proposalId) external onlyListedOwner returns (bool) {
    return _voteProposal(proposalId, true);
  }

  // Negative vote
  function voteNegative(uint256 proposalId) external onlyListedOwner returns (bool) {
    return _voteProposal(proposalId, false);
  }

  // Execute a voted proposal
  function execute(uint256 proposalId) external onlyListedOwner returns (bool) {
    Proposal memory currentProposal = _proposalStorage[proposalId];
    int256 positiveVoted = _calculatePercent(currentProposal.vote);
    // If positiveVoted < 70%, It need to pass 50% and expired
    if (positiveVoted < 70) {
      require(block.timestamp > _proposalStorage[proposalId].expired, "MultiSig: Voting period wasn't over");
      require(positiveVoted >= 50, 'MultiSig: Vote was not pass 50%');
    }
    require(currentProposal.executed == false, 'MultiSig: Proposal was executed');
    if (currentProposal.delegate) {
      currentProposal.target.functionDelegateCall(currentProposal.data);
    } else {
      if (currentProposal.target.isContract()) {
        currentProposal.target.functionCallWithValue(currentProposal.data, currentProposal.value);
      } else {
        payable(address(currentProposal.target)).transfer(currentProposal.value);
      }
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

  function _calculatePercent(int256 votedOwner) private view returns (int256) {
    return (votedOwner * 10000) / int256(totalOwner() * 100);
  }

  /*******************************************************
   * View section
   ********************************************************/

  function proposalIndex() external view returns (uint256) {
    return _proposalIndex;
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
}
