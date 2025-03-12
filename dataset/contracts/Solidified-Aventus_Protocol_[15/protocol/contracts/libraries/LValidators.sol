pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";
import "./LAVTManager.sol";
// ONLY_IF_PROPOSALS_ON:
import "./LProposals.sol";
import "./LValidatorsChallenges.sol";
// :ONLY_IF_PROPOSALS_ON
import "./LValidatorsStorage.sol";

library LValidators {

  // See IValidatorsManager interface for logs description.
  event LogValidatorRegistered(address indexed validatorAddress, string evidenceUrl, string desc, uint deposit);
  event LogValidatorDeregistered(address indexed validatorAddress);
// ONLY_IF_PROPOSALS_ON:
  event LogValidatorChallenged(address indexed validatorAddress, uint indexed proposalId, uint lobbyingStart,
      uint votingStart, uint revealingStart, uint revealingEnd);
  event LogValidatorChallengeEnded(address indexed validatorAddress, uint indexed proposalId, uint votesFor, uint votesAgainst);
  event LogVoterWinningsClaimed(uint indexed proposalId);
// :ONLY_IF_PROPOSALS_ON

  modifier onlyAfterDeregistrationTime(IAventusStorage _storage, address _validatorAddress) {
    uint deregistrationTime = getDeregistrationTime(_storage, _validatorAddress);
    require(LAventusTime.getCurrentTime(_storage) >= deregistrationTime, "Validator cannot be deregistered yet");
    _;
  }

  modifier onlyIfNotAlreadyRegistered(IAventusStorage _storage, address _validatorAddress) {
    require(!isRegistered(_storage, _validatorAddress), "Validator must not be registered");
    _;
  }

  modifier onlyIfRegistered(IAventusStorage _storage, address _validatorAddress) {
    require(isRegistered(_storage, _validatorAddress), "Validator is not registered");
    _;
  }

  modifier onlyRegisteredAndNotUnderChallenge(IAventusStorage _storage, address _validatorAddress) {
    require(isRegisteredAndNotUnderChallenge(_storage, _validatorAddress), "Must be registered and not under challenge");
    _;
  }

  function registerValidator(IAventusStorage _storage, address _validatorAddress, string calldata _evidenceUrl,
      string calldata _desc)
    external
    onlyIfNotAlreadyRegistered(_storage, _validatorAddress)
  {
    require(bytes(_evidenceUrl).length != 0, "Validator requires a non-empty evidence URL");
    require(bytes(_desc).length != 0, "Validator requires a non-empty description");

    uint validatorDeposit = getNewValidatorDeposit(_storage);
    LAVTManager.lockDeposit(_storage, _validatorAddress, validatorDeposit);
    LValidatorsStorage.setDeposit(_storage, _validatorAddress, validatorDeposit);

    emit LogValidatorRegistered(_validatorAddress, _evidenceUrl, _desc, validatorDeposit);
  }

  function deregisterValidator(IAventusStorage _storage, address _validatorAddress)
    external
    onlyRegisteredAndNotUnderChallenge(_storage, _validatorAddress)
    onlyAfterDeregistrationTime(_storage, _validatorAddress)
  {
    unlockDeposit(_storage, _validatorAddress);

    // Reset back to as if the validator had never been registered.
    LValidatorsStorage.clearExpiryTime(_storage, _validatorAddress);

    emit LogValidatorDeregistered(_validatorAddress);
  }

  function challengeValidator(IAventusStorage _storage, address _validatorAddress)
    external
    onlyRegisteredAndNotUnderChallenge(_storage, _validatorAddress)
  {
// ONLY_IF_PROPOSALS_ON:
    uint lobbyingPeriod = LValidatorsStorage.getLobbyingPeriod(_storage);
    uint votingPeriod = LValidatorsStorage.getVotingPeriod(_storage);
    uint revealingPeriod = LValidatorsStorage.getRevealingPeriod(_storage);

    uint deposit = getExistingDeposit(_storage, _validatorAddress);
    uint proposalId = LProposals.createProposal(_storage, deposit, lobbyingPeriod, votingPeriod, revealingPeriod);
    LValidatorsStorage.setChallengeProposalId(_storage, _validatorAddress, proposalId);
    (uint lobbyingStart, uint votingStart, uint revealingStart, uint revealingEnd) =
        LProposals.getTimestamps(_storage, proposalId);
    emit LogValidatorChallenged(_validatorAddress, proposalId, lobbyingStart, votingStart, revealingStart, revealingEnd);
// :ONLY_IF_PROPOSALS_ON
  }

  function endValidatorChallenge(IAventusStorage _storage, address _validatorAddress)
    external
  {
// ONLY_IF_PROPOSALS_ON:
    uint proposalId = LValidatorsStorage.getChallengeProposalId(_storage, _validatorAddress);
    require(proposalId != 0, "Challenge does not exist");

    (uint votesFor, uint votesAgainst) = LProposals.endProposal(_storage, proposalId);
    finaliseChallenge(_storage, proposalId, _validatorAddress);

    emit LogValidatorChallengeEnded(_validatorAddress, proposalId, votesFor, votesAgainst);
// :ONLY_IF_PROPOSALS_ON
  }

  function getExistingValidatorDeposit(IAventusStorage _storage, address _validatorAddress)
    external
    view
    onlyIfRegistered(_storage, _validatorAddress)
    returns (uint validatorDepositInAVT_)
  {
    validatorDepositInAVT_ = getExistingDeposit(_storage, _validatorAddress);
  }

  function ensureValidatorIsRegistered(IAventusStorage _storage)
    external
    view
  {
    require(isRegistered(_storage, msg.sender), "Sender must be a registered validator");
  }

  function updateExpiryTimeIfNecessary(IAventusStorage _storage, address _validatorAddress, uint _expiryTime)
    external
  {
    LValidatorsStorage.updateExpiryTimeIfNecessary(_storage, _validatorAddress, _expiryTime);
  }

  function validatorFailedRootChallenge(IAventusStorage _storage, address _validator)
    external
  {
    LValidatorsStorage.incrementValidatorFailedChallenges(_storage, _validator);
  }

  function claimVoterWinnings(IAventusStorage _storage, uint _proposalId)
    external
  {
// ONLY_IF_PROPOSALS_ON:
    LValidatorsChallenges.claimVoterWinnings(_storage, _proposalId);
    emit LogVoterWinningsClaimed(_proposalId);
// :ONLY_IF_PROPOSALS_ON
  }

  function isRegistered(IAventusStorage _storage, address _validatorAddress)
    public
    view
    returns (bool isRegistered_)
  {
    isRegistered_ = LValidatorsStorage.getDeposit(_storage, _validatorAddress) != 0;
  }

  function getNewValidatorDeposit(IAventusStorage _storage)
    public
    view
    returns (uint depositinAVT_)
  {
    depositinAVT_ = LValidatorsStorage.getFixedDepositAmount(_storage);
  }

  function getDeregistrationTime(IAventusStorage _storage, address _validatorAddress)
    public
    view
    returns (uint deregistrationTime_)
  {
    deregistrationTime_ = LValidatorsStorage.getDeregistrationTime(_storage, _validatorAddress);
  }

  function getExistingDeposit(IAventusStorage _storage, address _validatorAddress)
    private
    view
    returns (uint deposit_)
  {
    deposit_ = LValidatorsStorage.getDeposit(_storage, _validatorAddress);
  }

  function isRegisteredAndNotUnderChallenge(IAventusStorage _storage, address _validatorAddress)
    private
    view
    returns (bool ok_)
  {
    ok_ = isRegistered(_storage, _validatorAddress) && isNotUnderChallenge(_storage, _validatorAddress);
  }

  function unlockDeposit(IAventusStorage _storage, address _validatorAddress)
    private
  {
    uint deposit = getExistingDeposit(_storage, _validatorAddress);
    LAVTManager.unlockDeposit(_storage, _validatorAddress, deposit);
    LValidatorsStorage.setDeposit(_storage, _validatorAddress, 0);
  }

  function isNotUnderChallenge(IAventusStorage _storage, address _validatorAddress)
    private
    view
    returns (bool notUnderChallenge_)
  {
    notUnderChallenge_ = 0 == LValidatorsStorage.getChallengeProposalId(_storage, _validatorAddress);
  }

// ONLY_IF_PROPOSALS_ON:
  function setStatusFraudulent(IAventusStorage _storage, address _validatorAddress)
    private
  {
    setAsClearFromChallenge(_storage, _validatorAddress);

    // Validator is no longer valid; remove the expected deposit for the validator.
    unlockDeposit(_storage, _validatorAddress);
  }

  function setAsClearFromChallenge(IAventusStorage _storage, address _validatorAddress)
    private
  {
    LValidatorsStorage.setChallengeProposalId(_storage, _validatorAddress, 0);
  }

  function finaliseChallenge(IAventusStorage _storage, uint _proposalId, address _validatorAddress)
    private
  {
    uint totalAgreedStake = LProposals.getTotalRevealedStake(_storage, _proposalId, 1);
    uint totalDisagreedStake = LProposals.getTotalRevealedStake(_storage, _proposalId, 2);

    // Note: a "draw" is taken as the community NOT agreeing with the challenge.
    bool challengeWon = totalAgreedStake > totalDisagreedStake;

    // Get deposit now in case it is cleared by marking as fraudulent.
    uint deposit = getExistingDeposit(_storage, _validatorAddress);
    address challenger = LProposals.getOwner(_storage, _proposalId);
    address challengee = _validatorAddress;
    uint winningOption;
    address winner;
    address loser;
    uint totalWinningStake;

    if (challengeWon) {
      winningOption = 1;
      winner = challenger;
      loser = challengee;
      totalWinningStake = totalAgreedStake;
      setStatusFraudulent(_storage, _validatorAddress);
    } else {
      winningOption = 2;
      winner = challengee;
      loser = challenger;
      totalWinningStake = totalDisagreedStake;
      setAsClearFromChallenge(_storage, _validatorAddress);
    }

    bool winningsForVoters = totalWinningStake != 0;
    LValidatorsChallenges.doWinningsDistribution(_storage, _proposalId, winningsForVoters, deposit, winner, loser);

    // Save the information we need to calculate voter winnings when they make their claim.
    LProposals.setWinningProposalOption(_storage, _proposalId, winningOption);
    LProposals.setTotalWinningStake(_storage, _proposalId, totalWinningStake);
  }
// :ONLY_IF_PROPOSALS_ON
}