pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAVTManager.sol";
import "./zeppelin/LECRecovery.sol";
import "./LProposalsEnact.sol";
import "./LProposalsStorage.sol";

library LProposalsVoting {

  modifier onlyInVotingPeriodOrAfterRevealingFinished(IAventusStorage _storage, uint _proposalId) {
    bool inVotingPeriodOrAfterRevealing = LProposalsEnact.inVotingPeriodOrAfterRevealingFinished(_storage, _proposalId);
    require(inVotingPeriodOrAfterRevealing, "Proposal must be in the voting period or after revealing finished");
    _;
  }

  modifier onlyInRevealingPeriodOrLater(IAventusStorage _storage, uint _proposalId) {
    require(LProposalsEnact.inRevealingPeriodOrLater(_storage, _proposalId), "Must be in revealing phase or later");
    _;
  }

  modifier onlyUnrevealedVote(IAventusStorage _storage, uint _proposalId) {
    bytes32 secret = LProposalsStorage.getVoterSecret(_storage, msg.sender, _proposalId);
    require(secret != 0, "Sender must have a non revealed vote");
    _;
  }

  modifier onlyWhenVoterIsSender(uint _proposalId, uint _optId, bytes memory _signedMessage) {
    require(checkVoterIsSender(_proposalId, _optId, _signedMessage), "Voter must be the sender");
    _;
  }

  modifier onlyValidOptionId(uint _optId) {
    require (_optId == 1 || _optId == 2, "Invalid option");
    _;
  }

  function castVote(IAventusStorage _storage, uint _proposalId, bytes32 _secret)
    external
  {
    require(LProposalsStorage.getVoterSecret(_storage, msg.sender, _proposalId) == 0, "Already voted");
    LProposalsStorage.setVoterSecret(_storage, msg.sender, _proposalId, _secret);
    uint unrevealedVotesCount = LProposalsStorage.getUnrevealedVotesCount(_storage, _proposalId);
    LProposalsStorage.setUnrevealedVotesCount(_storage, _proposalId, unrevealedVotesCount + 1);
  }

  function cancelVote(IAventusStorage _storage, uint _proposalId)
    external
    onlyInVotingPeriodOrAfterRevealingFinished(_storage, _proposalId)
    onlyUnrevealedVote(_storage, _proposalId)
  {
    doRemoveVote(_storage, _proposalId);
  }

  function revealVote(IAventusStorage _storage, bytes memory _signedMessage, uint _proposalId, uint _optId)
    public
    onlyInRevealingPeriodOrLater(_storage, _proposalId)
    onlyValidOptionId(_optId)
    onlyWhenVoterIsSender(_proposalId, _optId, _signedMessage)
  {
    bytes32 storedVote = LProposalsStorage.getVoterSecret(_storage, msg.sender, _proposalId);
    require(storedVote == keccak256(abi.encodePacked(_signedMessage)), "Stored vote must be the same as the revealed one");

    // IFF we are still in the reveal period then add any stake
    if (LProposalsEnact.inRevealingPeriod(_storage, _proposalId))
      addVoterStakeToProposal(_storage, _proposalId, _optId, msg.sender);

    doRemoveVote(_storage, _proposalId);
  }

  function doRemoveVote(IAventusStorage _storage, uint _proposalId)
    private
  {
    uint unrevealedVotesCount = LProposalsStorage.getUnrevealedVotesCount(_storage, _proposalId);
    LProposalsStorage.setUnrevealedVotesCount(_storage, _proposalId, unrevealedVotesCount - 1);
    LProposalsStorage.setVoterSecret(_storage, msg.sender, _proposalId, 0);
  }

  function checkVoterIsSender(uint _proposalId, uint _optId, bytes memory _signedMessage)
    private
    view
    returns (bool voterIsSender_)
  {
    // Get voter public key from message and signature
    bytes32 msgHash = keccak256(abi.encodePacked((_proposalId * 10) + _optId));
    address voter = LECRecovery.recover(msgHash, _signedMessage);
    voterIsSender_ = voter == msg.sender;
  }

  function addVoterStakeToProposal(IAventusStorage _storage, uint _proposalId, uint _optId, address _voter)
    private
  {
    uint proposalRevealTime = LProposalsStorage.getRevealingStart(_storage, _proposalId);
    uint stake = LAVTManager.getHistoricBalance(_storage, _voter, proposalRevealTime);

    if (stake == 0)
      return;

    LProposalsStorage.increaseTotalRevealedStake(_storage, _proposalId, _optId, stake);
    LProposalsStorage.incrementNumVotersRevealedWithStake(_storage, _proposalId, _optId);
    LProposalsStorage.setRevealedVoterStake(_storage, _proposalId, _voter, _optId, stake);
  }
}