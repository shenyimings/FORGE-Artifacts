pragma solidity 0.5.12;

import "../../interfaces/IAventusStorage.sol";

library LProposalForTesting {

  /// See IProposalsManager interface for events description
  event LogCommunityProposalCreated(uint indexed proposalId, address indexed sender, string desc, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd, uint deposit);

  function createCommunityProposal(IAventusStorage, string memory)
    public
    returns (uint proposalId_)
  {
    proposalId_ = 2018;
    emit LogCommunityProposalCreated(proposalId_, msg.sender, "Test", 0, 0, 0, 0, 0);
  }

  function getCommunityProposalDeposit(IAventusStorage)
    pure
    public
    returns (uint result_)
  {
    result_ = 10;
  }

  function endCommunityProposal(IAventusStorage, uint, string memory)
    public
    pure
  {
    // This method has a different set of input parameters to the original.
  }
}