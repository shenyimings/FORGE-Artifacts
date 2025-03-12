pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAventusTime.sol";
import "./LAVTManager.sol";
import "./LProposalsStorage.sol";

// Library for extending voting protocol functionality
library LProposalsEnact {

  enum ProposalStatus {NonExistent, Lobbying, Voting, Revealing, RevealingFinishedProposalNotEnded, Ended}

  function doUnlockProposalDeposit(IAventusStorage _storage, uint _proposalId)
    external
  {
    address proposalOwner = getProposalOwner(_storage, _proposalId);
    uint proposalDeposit = getProposalDeposit(_storage, _proposalId);
    LAVTManager.unlockDeposit(_storage, proposalOwner, proposalDeposit);
    LProposalsStorage.setDeposit(_storage, _proposalId, 0);
  }

  function doCreateProposal(IAventusStorage _storage, uint _deposit, uint lobbyingPeriod, uint votingPeriod,
      uint revealingPeriod)
    external
    returns (uint proposalId_)
  {
    address owner = msg.sender;
    LAVTManager.lockDeposit(_storage, owner, _deposit);

    proposalId_ = LProposalsStorage.nextProposalId(_storage);
    LProposalsStorage.setOwner(_storage, proposalId_, owner);
    LProposalsStorage.setDeposit(_storage, proposalId_, _deposit);
    setProposalTimes(_storage, proposalId_, lobbyingPeriod, votingPeriod, revealingPeriod);
  }

  function inRevealingPeriodOrLater(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool result_)
  {
    ProposalStatus proposalStatus = doGetProposalStatus(_storage, _proposalId);
    result_ =
      (proposalStatus == ProposalStatus.Revealing) ||
      (proposalStatus == ProposalStatus.RevealingFinishedProposalNotEnded) ||
      (proposalStatus == ProposalStatus.Ended);
  }

  function inRevealingPeriod(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool result_)
  {
    result_ = doGetProposalStatus(_storage, _proposalId) == LProposalsEnact.ProposalStatus.Revealing;
  }

  function inVotingPeriodOrAfterRevealingFinished(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool result_)
  {
    ProposalStatus proposalStatus = doGetProposalStatus(_storage, _proposalId);
    result_ =
      proposalStatus == LProposalsEnact.ProposalStatus.Voting ||
      (proposalStatus == LProposalsEnact.ProposalStatus.RevealingFinishedProposalNotEnded) ||
      (proposalStatus == LProposalsEnact.ProposalStatus.Ended);
  }

  function inVotingPeriod(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool result_)
  {
    result_ = doGetProposalStatus(_storage, _proposalId) == LProposalsEnact.ProposalStatus.Voting;
  }

  function afterRevealingFinishedAndProposalNotEnded(IAventusStorage _storage, uint _proposalId)
    external
    view
    returns (bool result_)
  {
    result_ = doGetProposalStatus(_storage, _proposalId) == LProposalsEnact.ProposalStatus.RevealingFinishedProposalNotEnded;
  }

  function implementGovernanceProposal(IAventusStorage _storage, bytes memory _bytecode)
    public
    returns (bool success_)
  {
    (address contractAddress, bytes memory bytecode, bytes memory remainingBytecode) =
        abi.decode(_bytecode, (address, bytes, bytes));

    (success_,) = contractAddress.call(bytecode);

    require(success_);

    if (remainingBytecode.length != 0)
      implementGovernanceProposal(_storage, remainingBytecode);
  }

  function doGetProposalStatus(IAventusStorage _storage, uint _proposalId)
    public
    view
    returns (ProposalStatus status_)
  {
    uint votingStart = LProposalsStorage.getVotingStart(_storage, _proposalId);
    uint revealingStart = LProposalsStorage.getRevealingStart(_storage, _proposalId);
    uint revealingEnd = LProposalsStorage.getRevealingEnd(_storage, _proposalId);
    uint deposit = getProposalDeposit(_storage, _proposalId);
    uint currentTime = LAventusTime.getCurrentTime(_storage);

    if (votingStart == 0)
      status_ = ProposalStatus.NonExistent;
    else if (currentTime < votingStart)
      status_ = ProposalStatus.Lobbying;
    else if (currentTime < revealingStart)
      status_ = ProposalStatus.Voting;
    else if (currentTime < revealingEnd && thereAreUnrevealedVotes(_storage, _proposalId))
      status_ = ProposalStatus.Revealing;
    else if (deposit != 0)
      status_ = ProposalStatus.RevealingFinishedProposalNotEnded;
    else
      status_ = ProposalStatus.Ended;
  }

  function setProposalTimes(IAventusStorage _storage, uint _proposalId, uint lobbyingPeriod, uint votingPeriod,
      uint revealingPeriod)
    private
  {
    uint lobbyingStart = LAventusTime.getCurrentTime(_storage);
    uint votingStart = lobbyingStart + lobbyingPeriod;
    uint revealingStart = votingStart + votingPeriod;
    uint revealingEnd = revealingStart + revealingPeriod;

    LProposalsStorage.setLobbyingStart(_storage, _proposalId, lobbyingStart);
    LProposalsStorage.setVotingStart(_storage, _proposalId, votingStart);
    LProposalsStorage.setRevealingStart(_storage, _proposalId, revealingStart);
    LProposalsStorage.setRevealingEnd(_storage, _proposalId, revealingEnd);
  }

  function getProposalDeposit(IAventusStorage _storage, uint _proposalId)
    private
    view
    returns (uint deposit_)
  {
    deposit_ = LProposalsStorage.getDeposit(_storage, _proposalId);
  }

  function getProposalOwner(IAventusStorage _storage, uint _proposalId)
    private
    view
    returns (address owner_)
  {
    owner_ = LProposalsStorage.getOwner(_storage, _proposalId);
  }

  function thereAreUnrevealedVotes(IAventusStorage _storage, uint _proposalId)
    private
    view
    returns (bool result_)
  {
    result_ = LProposalsStorage.getUnrevealedVotesCount(_storage, _proposalId) != 0;
  }
}