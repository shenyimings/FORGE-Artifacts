pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAVTManager.sol";
import "./LProposals.sol";
import "./LValidatorsStorage.sol";

/**
 * Library for dealing with the winnings of a validator challenge.
 *
 * This is only used by, and is separate to, LValidators because of size limitations when deploying.
 * There is no proxy for this library.
 */

library LValidatorsChallenges {

  function claimVoterWinnings(IAventusStorage _storage, uint _proposalId)
    external
  {
    address voter = msg.sender;
    uint winningOption = LProposals.getWinningProposalOption(_storage, _proposalId);
    uint voterStake = LProposals.getRevealedVoterStake(_storage, _proposalId, voter, winningOption);
    require(voterStake != 0, "Voter has no winnings for this proposal");

    uint totalWinnings = LProposals.getTotalWinningsToVoters(_storage, _proposalId);
    assert(totalWinnings != 0);
    uint totalWinningStake = LProposals.getTotalWinningStake(_storage, _proposalId);
    assert(totalWinningStake != 0);

    uint voterReward;
    bool lastClaimant = LProposals.getNumVotersRevealedWithStake(_storage, _proposalId, winningOption) ==
        LProposals.incrementNumVotersClaimed(_storage, _proposalId);

    if (lastClaimant)
      voterReward = LProposals.getVotersWinningsPot(_storage, _proposalId);
    else
      voterReward = (totalWinnings * voterStake) / totalWinningStake;

    giveWinnings(_storage, voterReward, voter);
    LProposals.reduceVotersWinningsPot(_storage, _proposalId, voterReward);
    assert(!lastClaimant || LProposals.getVotersWinningsPot(_storage, _proposalId) == 0);

    // Stop the voter from claiming again.
    LProposals.clearRevealedStake(_storage, _proposalId, voter, winningOption);
  }

  function doWinningsDistribution(IAventusStorage _storage, uint _proposalId, bool _distributeToVoters, uint _winnings,
      address _winner, address _loser)
    external
  {
    takeAllWinningsFromProposalLoser(_storage, _winnings, _loser);
    uint winningsForChallengeWinnerPercentage = LValidatorsStorage.getWinningsForChallengeWinnerPercentage(_storage);
    uint winningsToProposalWinnerAVT = (_winnings * winningsForChallengeWinnerPercentage) / 100;
    giveWinnings(_storage, winningsToProposalWinnerAVT, _winner);

    uint winningsToChallengeEnderPercentage = LValidatorsStorage.getWinningsForChallengeEnderPercentage(_storage);
    address challengeEnder = msg.sender;
    uint winningsToChallengeEnderAVT = (_winnings * winningsToChallengeEnderPercentage) / 100;
    uint winningsForVoters = _winnings - winningsToProposalWinnerAVT - winningsToChallengeEnderAVT;

    if (_distributeToVoters) {
      // The rest of the winnings is distributed to the voters as they claim it.
      LProposals.setTotalWinningsToVoters(_storage, _proposalId, winningsForVoters);
      LProposals.initialiseVotersWinningsPot(_storage, _proposalId, winningsForVoters);
    } else {
      // If no one voted, the challenge ender gets the rest of the winnings.
      winningsToChallengeEnderAVT += winningsForVoters;
    }

    giveWinnings(_storage, winningsToChallengeEnderAVT, challengeEnder);
  }

  function takeAllWinningsFromProposalLoser(IAventusStorage _storage, uint _winnings, address _loser)
    private
  {
    LAVTManager.decreaseAVT(_storage, _loser, _winnings);
  }

  function giveWinnings(IAventusStorage _storage, uint _winnings, address _payee)
    private
  {
    LAVTManager.increaseAVT(_storage, _payee, _winnings);
  }
}