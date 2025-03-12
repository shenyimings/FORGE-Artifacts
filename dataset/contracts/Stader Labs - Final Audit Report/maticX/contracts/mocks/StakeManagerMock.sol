// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "../interfaces/IStakeManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../mocks/ValidatorShareMock.sol";

contract StakeManagerMock is IStakeManager {
	event UpdateSigner(uint256 validatorId, bytes signerPubkey);
	event UpdateCommissionRate(uint256 validatorId, uint256 newCommissionRate);

	mapping(uint256 => IStakeManager.Validator) smValidators;
	struct State {
		address token;
		address stakeNFT;
		uint256 id;
		mapping(address => uint256) validators;
		mapping(uint256 => address) Owners;
		mapping(uint256 => uint256) stakedAmount;
		mapping(uint256 => address) signer;
		mapping(uint256 => address) validatorShares;
		mapping(address => uint256) delegator2Amount;
		uint256 epoch;
	}

	State private state;

	constructor(address _token, address _stakeNFT) {
		state.token = _token;
		state.stakeNFT = _stakeNFT;
	}

	function unstake(uint256 _validatorId) external override {
		smValidators[_validatorId].deactivationEpoch = block.timestamp;
	}

	function createValidator(uint256 _validatorId) external override {
		smValidators[_validatorId] = IStakeManager.Validator({
			amount: 0,
			reward: 0,
			activationEpoch: block.timestamp,
			deactivationEpoch: 0,
			jailTime: 0,
			signer: address(this),
			contractAddress: address(
				new ValidatorShareMock(state.token, address(this), _validatorId)
			),
			status: IStakeManager.Status.Active,
			commissionRate: 0,
			lastCommissionUpdate: 0,
			delegatorsReward: 0,
			delegatedAmount: 0,
			initialRewardPerStake: 0
		});
		state.validatorShares[_validatorId] = address(
			new ValidatorShareMock(state.token, address(this), _validatorId)
		);
	}

	function getValidatorId(address _user)
		external
		view
		override
		returns (uint256)
	{
		return state.validators[_user];
	}

	function getValidatorContract(uint256 _validatorId)
		external
		view
		override
		returns (address)
	{
		return state.validatorShares[_validatorId];
	}

	function withdrawRewards(uint256) external override {
		IERC20(state.token).transfer(msg.sender, 1000);
	}

	function unstakeClaim(uint256 _validatorId) external override {
		IERC20(state.token).transfer(
			msg.sender,
			IERC20(state.token).balanceOf(address(this))
		);
		state.delegator2Amount[msg.sender] = 0;
		smValidators[_validatorId].status = IStakeManager.Status.Unstaked;
	}

	function validatorStake(uint256 _validatorId)
		external
		view
		override
		returns (uint256)
	{
		return state.stakedAmount[_validatorId];
	}

	function withdrawalDelay() external pure override returns (uint256) {
		return (2**13);
	}

	function delegationDeposit(
		uint256 _validatorId,
		uint256 _amount,
		address _delegator
	) external override returns (bool) {
		state.delegator2Amount[msg.sender] += _amount;
		state.stakedAmount[_validatorId] += _amount;
		IERC20(state.token).transferFrom(_delegator, address(this), _amount);
		return IERC20(state.token).transfer(msg.sender, _amount);
	}

	function epoch() external view override returns (uint256) {
		return state.epoch;
	}

	function slash(uint256 _validatorId) external {
		smValidators[_validatorId].status = IStakeManager.Status.Locked;
		state.stakedAmount[_validatorId] -= 100;
	}

	function validators(uint256 _validatorId)
		external
		view
		override
		returns (Validator memory)
	{
		return smValidators[_validatorId];
	}

	function setEpoch(uint256 _epoch) external {
		state.epoch = _epoch;
	}

	function migrateDelegation(
		uint256 _fromValidatorId,
		uint256 _toValidatorId,
		uint256 _amount
	) public override {
		state.stakedAmount[_fromValidatorId] -= _amount;
		state.stakedAmount[_toValidatorId] += _amount;
	}
}
