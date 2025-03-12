pragma solidity 0.5.12;

import "./interfaces/IAventusStorage.sol";
import "./interfaces/IProposalsManager.sol";
import "./libraries/LValidators.sol";
import "./libraries/LProposals.sol";
import "./Owned.sol";
import "./Versioned.sol";

contract ProposalsManager is IProposalsManager, Owned, Versioned {

  IAventusStorage public s;

  constructor(IAventusStorage _s)
    public
  {
    s = _s;
  }

  function createCommunityProposal(string calldata _desc)
    external
  {
    LProposals.createCommunityProposal(s, _desc);
  }

  function endCommunityProposal(uint _proposalId)
    external
  {
    LProposals.endCommunityProposal(s, _proposalId);
  }

  function createGovernanceProposal(string calldata _desc, bytes calldata _bytecode)
    external
  {
    LProposals.createGovernanceProposal(s, _desc, _bytecode);
  }

  function endGovernanceProposal(uint _proposalId)
    external
  {
    LProposals.endGovernanceProposal(s, _proposalId);
  }

  function castVote(uint _proposalId, bytes32 _secret)
    external
  {
    LProposals.castVote(s, _proposalId, _secret);
  }

  function cancelVote(uint _proposalId)
    external
  {
    LProposals.cancelVote(s, _proposalId);
  }

  function revealVote(bytes calldata _signedMessage, uint _proposalId, uint _optId)
    external
  {
    LProposals.revealVote(s, _signedMessage, _proposalId, _optId);
  }

  function claimVoterWinnings(uint _proposalId)
    external
  {
    LValidators.claimVoterWinnings(s, _proposalId);
  }

  function getCommunityProposalDeposit()
    external
    view
    returns (uint proposalDeposit_)
  {
    proposalDeposit_ = LProposals.getCommunityProposalDeposit(s);
  }

  function getGovernanceProposalDeposit()
    external
    view
    returns (uint proposalDeposit_)
  {
    proposalDeposit_ = LProposals.getGovernanceProposalDeposit(s);
  }

  function getAventusTime()
    external
    view
    returns (uint time_)
  {
    time_ = LProposals.getAventusTime(s);
  }

  function getVotingStartTime(uint _proposalId)
    external
    view
    returns (uint votingStartTime_)
  {
    votingStartTime_ = LProposals.getVotingStartTime(s, _proposalId);
  }

  function getVotingRevealStartTime(uint _proposalId)
    external
    view
    returns (uint votingRevealStartTime_)
  {
    votingRevealStartTime_ = LProposals.getVotingRevealStartTime(s, _proposalId);
  }

  function getVotingRevealEndTime(uint _proposalId)
    external
    view
    returns (uint votingRevealEndTime_)
  {
    votingRevealEndTime_ = LProposals.getVotingRevealEndTime(s, _proposalId);
  }
}