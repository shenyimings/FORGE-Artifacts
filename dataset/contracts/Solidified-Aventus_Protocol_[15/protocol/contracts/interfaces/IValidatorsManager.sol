pragma solidity 0.5.12;

interface IValidatorsManager {

  /**
   * @notice Event emitted for a registerValidator transaction.
   */
  event LogValidatorRegistered(address indexed validatorAddress, string evidenceUrl, string desc, uint deposit);

  /**
   * @notice Event emitted for a deregisterValidator transaction.
   */
  event LogValidatorDeregistered(address indexed validatorAddress);

  /**
   * @notice Event emitted for a challengeValidator transaction.
   */
  event LogValidatorChallenged(address indexed validatorAddress, uint indexed proposalId, uint lobbyingStart, uint votingStart,
      uint revealingStart, uint revealingEnd);

  /**
   * Event emitted for a endValidatorChallenge transaction.
   */
  event LogValidatorChallengeEnded(address indexed validatorAddress, uint indexed proposalId, uint votesFor, uint votesAgainst);

  /**
   * @notice Register the given address as a validator on the Aventus Protocol.
   * NOTE: requires a deposit to be made. See getValidatorDeposit().
   */
  function registerValidator(address _validatorAddress, string calldata _evidenceUrl, string calldata _desc) external;

  /**
   * @notice Stop the given validator from using the Aventus Protocol. This will unlock
   * the deposit that was locked when the validator was registered.
   */
  function deregisterValidator(address _validatorAddress) external;

  /**
   * @notice Get the deposit value in AVT - to 18 sig fig - required to register a validator.
   * See registerValidator().
   */
  function getNewValidatorDeposit() external view returns (uint validatorDepositInAVT_);

  /**
   * @notice Create a challenge for the specified validator.
   * @param _validatorAddress address of validator to be challenged
   */
  function challengeValidator(address _validatorAddress) external;

  /**
   * @notice Ends a challenge on the specified validator.
   * @param _validatorAddress address of validator to be cleared of challenge
   */
  function endValidatorChallenge(address _validatorAddress) external;

  /**
   * @notice Gets the deposit paid for the specified validator.
   */
  function getExistingValidatorDeposit(address _validatorAddress) external view returns (uint validatorDepositInAVT_);

  /**
   * @return true if the given validator is allowed to use the Aventus Protocol.
   * ie has a deposit locked up against this address.
   */
  function validatorIsRegistered(address _validatorAddress) external view returns (bool isRegistered_);

  /**
  * @return Timestamp of when this validator can be deregistered; zero if no restrictions.
  */
  function getDeregistrationTime(address _validatorAddress) external view returns (uint deregistrationTime_);
}