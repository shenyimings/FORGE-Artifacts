// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./IValidatorShare.sol";
import "./IValidatorRegistry.sol";

/// @title MaticX interface.
interface IMaticX is IERC20Upgradeable {
	struct WithdrawalRequest {
		uint256 validatorNonce;
		uint256 requestEpoch;
		address validatorAddress;
	}

	function version() external view returns (string memory);

	function treasury() external view returns (address);

	function feePercent() external view returns (uint8);

	function instantPoolOwner() external view returns (address);

	function instantPoolMatic() external view returns (uint256);

	function instantPoolMaticX() external view returns (uint256);

	function initialize(
		address _validatorRegistry,
		address _stakeManager,
		address _token,
		address _manager,
		address _instant_pool_manager,
		address _treasury
	) external;

	function provideInstantPoolMatic(uint256 _amount) external;

	function provideInstantPoolMaticX(uint256 _amount) external;

	function withdrawInstantPoolMaticX(uint256 _amount) external;

	function withdrawInstantPoolMatic(uint256 _amount) external;

	function mintMaticXToInstantPool() external;

	function swapMaticForMaticXViaInstantPool(uint256 _amount) external;

	function submit(uint256 _amount) external returns (uint256);

	function requestWithdraw(uint256 _amount) external;

	function claimWithdrawal(uint256 _idx) external;

	function withdrawRewards(uint256 _validatorId) external returns (uint256);

	function stakeRewardsAndDistributeFees(uint256 _validatorId) external;

	function migrateDelegation(
		uint256 _fromValidatorId,
		uint256 _toValidatorId,
		uint256 _amount
	) external;

	function togglePause() external;

	function convertMaticXToMatic(uint256 _balance)
		external
		view
		returns (
			uint256,
			uint256,
			uint256
		);

	function convertMaticToMaticX(uint256 _balance)
		external
		view
		returns (
			uint256,
			uint256,
			uint256
		);

	function setFeePercent(uint8 _feePercent) external;

	function setInstantPoolOwner(address _address) external;

	function setValidatorRegistry(address _address) external;

	function setTreasury(address _address) external;

	function setVersion(string calldata _version) external;

	function getUserWithdrawalRequests(address _address)
		external
		view
		returns (WithdrawalRequest[] memory);

	function getSharesAmountOfUserWithdrawalRequest(
		address _address,
		uint256 _idx
	) external view returns (uint256);

	function getTotalStake(IValidatorShare _validatorShare)
		external
		view
		returns (uint256, uint256);

	function getTotalStakeAcrossAllValidators() external view returns (uint256);

	function getTotalPooledMatic() external view returns (uint256);

	function getContracts()
		external
		view
		returns (
			address _stakeManager,
			address _polygonERC20,
			address _validatorRegistry
		);

	event Submit(address indexed _from, uint256 _amount);
	event Delegate(uint256 indexed _validatorId, uint256 _amountDelegated);
	event RequestWithdraw(
		address indexed _from,
		uint256 _amountMaticX,
		uint256 _amountMatic
	);
	event ClaimWithdrawal(
		address indexed _from,
		uint256 indexed _idx,
		uint256 _amountClaimed
	);
	event WithdrawRewards(uint256 indexed _validatorId, uint256 _rewards);
	event StakeRewards(uint256 indexed _validatorId, uint256 _amountStaked);
	event DistributeFees(address indexed _address, uint256 _amount);
	event MigrateDelegation(
		uint256 indexed _fromValidatorId,
		uint256 indexed _toValidatorId,
		uint256 _amount
	);
	event SetFeePercent(uint8 _feePercent);
	event SetInstantPoolOwner(address _address);
	event SetTreasury(address _address);
	event SetValidatorRegistry(address _address);
	event SetVersion(string _version);
}
