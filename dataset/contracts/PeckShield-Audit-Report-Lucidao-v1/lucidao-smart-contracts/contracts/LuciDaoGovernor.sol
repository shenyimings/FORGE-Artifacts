// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorProposalThresholdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract LucidaoGovernor is
	Initializable,
	GovernorUpgradeable,
	GovernorProposalThresholdUpgradeable,
	GovernorCountingSimpleUpgradeable,
	GovernorVotesUpgradeable,
	GovernorVotesQuorumFractionUpgradeable,
	GovernorTimelockControlUpgradeable
{
	function initialize(ERC20VotesUpgradeable _token, TimelockControllerUpgradeable _timelock) public initializer {
		__Governor_init("LucidaoGovernor");
		__GovernorProposalThreshold_init();
		__GovernorCountingSimple_init();
		__GovernorVotes_init(_token);
		// 4% quorum
		__GovernorVotesQuorumFraction_init(4);
		__GovernorTimelockControl_init(_timelock);
	}

	function votingDelay() public pure override returns (uint256) {
		return 50233; // on average 12 hours on Fantom with a block time of 0.86s
	}

	function votingPeriod() public pure override returns (uint256) {
		return 301398; // on average 3 days
	}

	function proposalThreshold() public pure override returns (uint256) {
		return 8800000e18;
	}

	// The following functions are overrides required by Solidity.

	function quorum(uint256 blockNumber) public view override(IGovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable) returns (uint256) {
		return super.quorum(blockNumber);
	}

	function getVotes(address account, uint256 blockNumber) public view override(IGovernorUpgradeable, GovernorVotesUpgradeable) returns (uint256) {
		return super.getVotes(account, blockNumber);
	}

	function state(uint256 proposalId) public view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (ProposalState) {
		return super.state(proposalId);
	}

	function propose(
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		string memory description
	) public override(GovernorUpgradeable, GovernorProposalThresholdUpgradeable, IGovernorUpgradeable) returns (uint256) {
		return super.propose(targets, values, calldatas, description);
	}

	function _execute(
		uint256 proposalId,
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		bytes32 descriptionHash
	) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
		super._execute(proposalId, targets, values, calldatas, descriptionHash);
	}

	function _cancel(
		address[] memory targets,
		uint256[] memory values,
		bytes[] memory calldatas,
		bytes32 descriptionHash
	) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
		return super._cancel(targets, values, calldatas, descriptionHash);
	}

	function _executor() internal view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (address) {
		return super._executor();
	}

	function supportsInterface(bytes4 interfaceId) public view override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
