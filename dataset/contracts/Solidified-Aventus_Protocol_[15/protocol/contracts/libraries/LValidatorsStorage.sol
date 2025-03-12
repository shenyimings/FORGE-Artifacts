pragma solidity 0.5.12;

import "../interfaces/IAventusStorage.sol";

library LValidatorsStorage {

  string constant validatorsTable = "Validators";
  string constant validatorTable = "Validator";
  bytes32 constant numValidatorCoolingOffPeriodsKey =
      keccak256(abi.encodePacked(validatorsTable, "NumValidatorCoolingOffPeriods"));
  bytes32 constant depositKey = keccak256(abi.encodePacked(validatorsTable, "FixedDepositAmount"));
  bytes32 constant challengeLobbyingPeriodKey = keccak256(abi.encodePacked(validatorsTable, "ChallengeLobbyingPeriod"));
  bytes32 constant challengeVotingPeriodKey = keccak256(abi.encodePacked(validatorsTable, "ChallengeVotingPeriod"));
  bytes32 constant challengeRevealingPeriodKey = keccak256(abi.encodePacked(validatorsTable, "ChallengeRevealingPeriod"));
  bytes32 constant winningsForChallengeWinnerPercentageKey = keccak256(abi.encodePacked(validatorsTable,
      "WinningsForChallengeWinnerPercentage"));
  bytes32 constant winningsForChallengeEnderPercentageKey = keccak256(abi.encodePacked(validatorsTable,
      "WinningsForChallengeEnderPercentage"));

  function getFixedDepositAmount(IAventusStorage _storage)
    external
    view
    returns (uint fixedDepositAmount_)
  {
    fixedDepositAmount_ = _storage.getUInt(depositKey);
  }

  function getDeregistrationTime(IAventusStorage _storage, address _validatorAddress)
    external
    view
    returns (uint deregistrationTime_)
  {
    bytes32 key = keccak256(abi.encodePacked(validatorTable, _validatorAddress, "ExpiryTime"));
    uint expiryTime = _storage.getUInt(key);
    if (expiryTime != 0) {
      uint coolingOffPeriod = getCoolingOffPeriod(_storage, _validatorAddress);
      deregistrationTime_ = expiryTime + coolingOffPeriod;
    }
  }

  function updateExpiryTimeIfNecessary(IAventusStorage _storage, address _validatorAddress, uint _expiryTime)
    external
  {
    bytes32 key = keccak256(abi.encodePacked(validatorTable, _validatorAddress, "ExpiryTime"));
    if (_expiryTime > _storage.getUInt(key))
      _storage.setUInt(key, _expiryTime);
  }

  function clearExpiryTime(IAventusStorage _storage, address _validatorAddress)
    external
  {
    bytes32 key = keccak256(abi.encodePacked(validatorTable, _validatorAddress, "ExpiryTime"));
    _storage.setUInt(key, 0);

    clearValidatorFailedChallenges(_storage, _validatorAddress);
  }

  function incrementValidatorFailedChallenges(IAventusStorage _storage, address _validator)
    external
  {
    bytes32 numFailedChallengesKey = keccak256(abi.encodePacked(validatorTable, _validator, "ValidatorFailedChallenges"));
    uint numFailedChallenges = _storage.getUInt(numFailedChallengesKey);
    _storage.setUInt(numFailedChallengesKey, ++numFailedChallenges);
  }

  function clearValidatorFailedChallenges(IAventusStorage _storage, address _validator)
    private
  {
    bytes32 numFailedChallengesKey = keccak256(abi.encodePacked(validatorTable, _validator, "ValidatorFailedChallenges"));
    _storage.setUInt(numFailedChallengesKey, 0);
  }

  function getCoolingOffPeriod(IAventusStorage _storage, address _validatorAddress)
    private
    view
    returns (uint coolingOffPeriod_)
  {
    bytes32 numFailedChallengesKey = keccak256(abi.encodePacked(validatorTable, _validatorAddress, "ValidatorFailedChallenges"));
    uint numFailedChallenges = _storage.getUInt(numFailedChallengesKey);
    uint numValidatorCoolingOffPeriods = _storage.getUInt(numValidatorCoolingOffPeriodsKey);

    if (numFailedChallenges > numValidatorCoolingOffPeriods - 1)
      numFailedChallenges = numValidatorCoolingOffPeriods - 1;

    bytes32 coolingOffPeriodKey = keccak256(abi.encodePacked(validatorsTable, "ValidatorCoolingOffPeriod", numFailedChallenges));
    coolingOffPeriod_ = _storage.getUInt(coolingOffPeriodKey);
  }

  function getLobbyingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint lobbyingPeriod_)
  {
    lobbyingPeriod_ = _storage.getUInt(challengeLobbyingPeriodKey);
  }

  function getVotingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint votingPeriod_)
  {
    votingPeriod_ = _storage.getUInt(challengeVotingPeriodKey);
  }

  function getRevealingPeriod(IAventusStorage _storage)
    external
    view
    returns (uint revealingPeriod_)
  {
    revealingPeriod_ = _storage.getUInt(challengeRevealingPeriodKey);
  }

  function getWinningsForChallengeWinnerPercentage(IAventusStorage _storage)
    external
    view
    returns (uint winnerPercentage_)
  {
    winnerPercentage_ = _storage.getUInt(winningsForChallengeWinnerPercentageKey);
  }

  function getWinningsForChallengeEnderPercentage(IAventusStorage _storage)
    external
    view
    returns (uint enderPercentage_)
  {
    enderPercentage_ = _storage.getUInt(winningsForChallengeEnderPercentageKey);
  }

  function getChallengeProposalId(IAventusStorage _storage, address _validatorAddress)
    external
    view
    returns (uint challengeProposalId_)
  {
    challengeProposalId_ = _storage.getUInt(keccak256(abi.encodePacked(validatorTable, _validatorAddress, "Challenge")));
  }

  function setChallengeProposalId(IAventusStorage _storage, address _validatorAddress, uint _challengeProposalId)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(validatorTable, _validatorAddress, "Challenge")), _challengeProposalId);
  }

  function getDeposit(IAventusStorage _storage, address _validatorAddress)
    external
    view
    returns (uint deposit_)
  {
    deposit_ = _storage.getUInt(keccak256(abi.encodePacked(validatorTable, _validatorAddress, "Deposit")));
  }

  function setDeposit(IAventusStorage _storage, address _validatorAddress, uint _deposit)
    external
  {
    _storage.setUInt(keccak256(abi.encodePacked(validatorTable, _validatorAddress, "Deposit")), _deposit);
  }
}