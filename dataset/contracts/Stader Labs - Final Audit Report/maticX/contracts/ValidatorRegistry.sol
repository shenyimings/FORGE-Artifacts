// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IValidatorRegistry.sol";
import "./interfaces/IMaticX.sol";
import "./interfaces/IStakeManager.sol";

/// @title ValidatorRegistry
/// @notice ValidatorRegistry is the main contract that manage validators
/// @dev ValidatorRegistry is the main contract that manage validators.
contract ValidatorRegistry is
	IValidatorRegistry,
	PausableUpgradeable,
	AccessControlUpgradeable,
	ReentrancyGuardUpgradeable
{
	address private stakeManager;
	address private polygonERC20;
	address private maticX;

	string public override version;
	uint256 public override preferredDepositValidatorId;
	uint256 public override preferredWithdrawalValidatorId;
	mapping(uint256 => bool) public override validatorIdExists;

	uint256[] private validators;

	/// -------------------------- initialize ----------------------------------

	/// @notice Initialize the ValidatorRegistry contract.
	function initialize(
		address _stakeManager,
		address _polygonERC20,
		address _maticX,
		address _manager
	) external initializer {
		__AccessControl_init();
		__Pausable_init();

		stakeManager = _stakeManager;
		polygonERC20 = _polygonERC20;
		maticX = _maticX;

		_setupRole(DEFAULT_ADMIN_ROLE, _manager);
	}

	/// ----------------------------- API --------------------------------------

	/// @notice Allows a validator that was already staked on the polygon stake manager
	/// to join the MaticX protocol.
	/// @param _validatorId id of the validator.
	function addValidator(uint256 _validatorId)
		external
		override
		whenNotPaused
		whenValidatorIdDoesNotExist(_validatorId)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		IStakeManager.Validator memory smValidator = IStakeManager(stakeManager)
			.validators(_validatorId);

		require(
			smValidator.contractAddress != address(0),
			"Validator has no ValidatorShare"
		);
		require(
			(smValidator.status == IStakeManager.Status.Active) &&
				smValidator.deactivationEpoch == 0,
			"Validator isn't ACTIVE"
		);

		validators.push(_validatorId);
		validatorIdExists[_validatorId] = true;

		emit AddValidator(_validatorId);
	}

	/// @notice Allows to remove an validator from the registry.
	/// @param _validatorId the validator id.
	function removeValidator(uint256 _validatorId)
		external
		override
		whenNotPaused
		whenValidatorIdExists(_validatorId)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		require(
			preferredDepositValidatorId != _validatorId,
			"Can't remove a preferred validator for deposits"
		);
		require(
			preferredWithdrawalValidatorId != _validatorId,
			"Can't remove a preferred validator for withdrawals"
		);

		address validatorShare = IStakeManager(stakeManager)
			.getValidatorContract(_validatorId);
		(uint256 validatorBalance, ) = IValidatorShare(validatorShare)
			.getTotalStake(address(this));
		require(validatorBalance == 0, "Validator has some shares left");

		// swap with the last item and pop it.
		uint256 validatorsLength = validators.length;
		for (uint256 idx = 0; idx < validatorsLength - 1; ++idx) {
			if (_validatorId == validators[idx]) {
				validators[idx] = validators[validatorsLength - 1];
				break;
			}
		}
		validators.pop();

		delete validatorIdExists[_validatorId];

		emit RemoveValidator(_validatorId);
	}

	/// -------------------------------Setters-----------------------------------

	/// @notice Allows to set the preffered validator id for deposits
	/// @param _validatorId the validator id.
	function setPreferredDepositValidatorId(uint256 _validatorId)
		external
		override
		whenNotPaused
		whenValidatorIdExists(_validatorId)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		preferredDepositValidatorId = _validatorId;

		emit SetPreferredDepositValidatorId(_validatorId);
	}

	/// @notice Allows to set the preffered validator id for withdrawals
	/// @param _validatorId the validator id.
	function setPreferredWithdrawalValidatorId(uint256 _validatorId)
		external
		override
		whenNotPaused
		whenValidatorIdExists(_validatorId)
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		preferredWithdrawalValidatorId = _validatorId;

		emit SetPreferredWithdrawalValidatorId(_validatorId);
	}

	/// @notice Allows to set the MaticX contract address.
	function setMaticX(address _maticX)
		external
		override
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		maticX = _maticX;

		emit SetMaticX(_maticX);
	}

	/// @notice Allows to set the contract version.
	/// @param _version contract version
	function setVersion(string memory _version)
		external
		override
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		version = _version;

		emit SetVersion(_version);
	}

	/// @notice Allows to pause the contract.
	function togglePause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
		paused() ? _unpause() : _pause();
	}

	/// -------------------------------Getters-----------------------------------

	/// @notice Get the maticX contract addresses
	function getContracts()
		external
		view
		override
		returns (
			address _stakeManager,
			address _polygonERC20,
			address _maticX
		)
	{
		_stakeManager = stakeManager;
		_polygonERC20 = polygonERC20;
		_maticX = maticX;
	}

	/// @notice Get validator id by its index.
	/// @param _index validator index
	function getValidatorId(uint256 _index)
		external
		view
		override
		returns (uint256)
	{
		return validators[_index];
	}

	/// @notice Get validators.
	function getValidators() external view override returns (uint256[] memory) {
		return validators;
	}

	/// -------------------------------Modifiers-----------------------------------

	/**
	 * @dev Modifier to make a function callable only when the validator id exists in our registry.
	 *
	 * Requirements:
	 *
	 * - The validator id must exist in our registry.
	 */
	modifier whenValidatorIdExists(uint256 _validatorId) {
		require(
			validatorIdExists[_validatorId] == true,
			"Validator id doesn't exist in our registry"
		);
		_;
	}

	/**
	 * @dev Modifier to make a function callable only when the validator id doesn't exist in our registry.
	 *
	 * Requirements:
	 *
	 * - The validator id must not exist in our registry.
	 */
	modifier whenValidatorIdDoesNotExist(uint256 _validatorId) {
		require(
			validatorIdExists[_validatorId] == false,
			"Validator id already exists in our registry"
		);
		_;
	}
}
