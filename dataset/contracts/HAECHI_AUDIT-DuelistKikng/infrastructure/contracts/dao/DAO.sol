// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Address.sol';
import '../interfaces/IDAO.sol';
import '../interfaces/IDAOToken.sol';
import '../libraries/RegistryUser.sol';

/**
 * DAO
 * Name: DAO
 * Domain: DKDAO, *
 */
contract DAO is RegistryUser, IDAO {
  // Address lib providing safe {call} and {delegatecall}
  using Address for address;

  // Proposal index, begin from 1
  uint256 private _proposalIndex;

  // Proposal storage
  mapping(uint256 => Proposal) private _proposalStorage;

  // Voted storage
  mapping(uint256 => mapping(address => bool)) private _votedStorage;

  // Create a new proposal
  event CreateProposal(uint256 indexed proposalId, bytes32 indexed proposalDigest, uint256 indexed expired);

  // Execute proposal
  event ExecuteProposal(uint256 indexed proposalId, address indexed trigger, int256 indexed vote);

  // Positive vote
  event PositiveVote(uint256 indexed proposalId, address indexed stakeholder, uint256 indexed power);

  // Negative vote
  event NegativeVote(uint256 indexed proposalId, address indexed stakeholder, uint256 indexed power);

  function init(address registry_, bytes32 domain_) external override returns (bool) {
    _registryUserInit(registry_, domain_);
    return true;
  }

  /*******************************************************
   * Stakeholder section
   ********************************************************/

  // Create a new proposal
  function createProposal(Proposal memory newProposal) external override returns (uint256) {
    uint256 votePower = IDAOToken(_getAddressSameDomain('DAOToken')).calculatePower(msg.sender);
    require(votePower > 0, 'DAO: Only allow stakeholder to vote');
    _proposalIndex += 1;
    newProposal.expired = uint64(block.timestamp + 3 days);
    newProposal.vote = 0;
    _proposalStorage[_proposalIndex] = newProposal;
    return _proposalIndex;
  }

  // Vote a proposal
  function voteProposal(uint256 proposalId, bool positive) external override returns (bool) {
    uint256 votePower = IDAOToken(_getAddressSameDomain('DAOToken')).calculatePower(msg.sender);
    require(block.timestamp < _proposalStorage[proposalId].expired, 'DAO: Voting period was over');
    require(votePower > 0, 'DAO: Only allow stakeholder to vote');
    require(_votedStorage[proposalId][msg.sender] == false, 'DAO: You had voted this proposal');
    if (positive) {
      _proposalStorage[proposalId].vote += int256(votePower);
      emit PositiveVote(proposalId, msg.sender, votePower);
    } else {
      _proposalStorage[proposalId].vote -= int256(votePower);
      emit NegativeVote(proposalId, msg.sender, votePower);
    }
    _votedStorage[proposalId][msg.sender] = true;
    return true;
  }

  /*******************************************************
   * Public section
   ********************************************************/

  // Execute a voted proposal
  function execute(uint256 proposalId) external override returns (bool) {
    Proposal memory currentProposal = _proposalStorage[proposalId];
    int256 threshold = int256(IDAOToken(_getAddressSameDomain('DAOToken')).totalSupply() / 2);
    require(block.timestamp > _proposalStorage[proposalId].expired, "DAO: Voting period wasn't over");
    require(currentProposal.vote > threshold, 'DAO: Vote was not pass threshold');
    require(currentProposal.executed == false, 'DAO: Proposal was executed');
    if (currentProposal.delegate) {
      currentProposal.target.functionDelegateCall(currentProposal.data);
    } else {
      currentProposal.target.functionCall(currentProposal.data);
    }
    currentProposal.executed = true;
    _proposalStorage[proposalId] = currentProposal;
    emit ExecuteProposal(proposalId, msg.sender, currentProposal.vote);
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  function getProposalIndex() external view returns (uint256) {
    return _proposalIndex;
  }

  function getProposalDetail(uint256 proposalId) external view returns (Proposal memory) {
    return _proposalStorage[proposalId];
  }

  function isVoted(address stakeholder, uint256 proposalId) external view returns (bool) {
    return _votedStorage[proposalId][stakeholder];
  }
}
