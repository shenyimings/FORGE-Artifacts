// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

/// @title IValidatorRegistry
/// @notice Node validator registry interface
interface IValidatorRegistry {
	function addValidator(uint256 _validatorId) external;

	function removeValidator(uint256 _validatorId) external;

	function setPreferredDepositValidatorId(uint256 _validatorId) external;

	function setPreferredWithdrawalValidatorId(uint256 _validatorId) external;

	function setMaticX(address _maticX) external;

	function setVersion(string memory _version) external;

	function togglePause() external;

	function version() external view returns (string memory);

	function preferredDepositValidatorId() external view returns (uint256);

	function preferredWithdrawalValidatorId() external view returns (uint256);

	function validatorIdExists(uint256 _validatorId)
		external
		view
		returns (bool);

	function getContracts()
		external
		view
		returns (
			address _stakeManager,
			address _polygonERC20,
			address _maticX
		);

	function getValidatorId(uint256 _index) external view returns (uint256);

	function getValidators() external view returns (uint256[] memory);

	event AddValidator(uint256 indexed _validatorId);
	event RemoveValidator(uint256 indexed _validatorId);
	event SetPreferredDepositValidatorId(uint256 indexed _validatorId);
	event SetPreferredWithdrawalValidatorId(uint256 indexed _validatorId);
	event SetMaticX(address _address);
	event SetVersion(string _version);
}
