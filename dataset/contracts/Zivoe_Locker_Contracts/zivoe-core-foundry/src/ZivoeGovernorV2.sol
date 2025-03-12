// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "./libraries/ZivoeGTC.sol";
import "./libraries/ZivoeTLC.sol";

import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorCountingSimple.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorSettings.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotes.sol";
import "../lib/openzeppelin-contracts/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";


interface IZivoeGlobals_ZVG {
    /// @notice Returns the address of the RewardsVesting ($stZVE) vesting contract.
    function stZVE() external view returns (address);

    /// @notice Returns the address of the ZivoeRewardsVesting ($vestZVE) vesting contract.
    function vestZVE() external view returns (address);
}

interface IZivoeRewards_ZVG {
    /// @notice Returns the amount of tokens owned by "account", received when depositing via stake().
    /// @param account The account to view information of.
    /// @return amount The amount of tokens owned by "account".
    function balanceOf(address account) external view returns (uint256 amount);

    /// @notice Returns the amount of votes that `account` had at the end of a past block (`blockNumber`).
    /// @param account The account to view information of.
    /// @return blockNumber The block.number to check historical record.
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}

interface IZivoeRewardsVesting_ZVG is IZivoeRewards_ZVG { }



/// @notice This contract is the governance contract.
///         This contract has the following responsibilities:
///          - Proposals are made here.
///          - Voting is conducted here.
///          - Increase voting power of stakers and vesters.
///          - Execute proposals.
///          - Interface with TimelockController (external contract) to facilitate execution.
contract ZivoeGovernorV2 is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, ZivoeGTC {
    
    // ---------------------
    //    State Variables
    // ---------------------
    
    address public immutable GBL;   /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the ZivoeGovernorV2 contract.
    /// @param _token       The token used for voting ($ZVE).
    /// @param _timelock    The timelock controller (ZivoeTLC).
    /// @param _GBL         The ZivoeGlobals contract.
    constructor(IVotes _token, ZivoeTLC _timelock, address _GBL)
        Governor("ZivoeGovernorV2") GovernorSettings(1, 3600, 100000 ether)
        GovernorVotes(_token) GovernorVotesQuorumFraction(10) ZivoeGTC(_timelock) { GBL = _GBL; }



    // ---------------
    //    Functions
    // ---------------

    /// @dev Utilize the ZivoeGTC contract which supports "Queued" state.
    function state(uint256 proposalId) public view override(Governor, ZivoeGTC) returns (ProposalState) {
        return ZivoeGTC.state(proposalId);
    }

    /// @dev Utilize the GovernorSettings contract which defines _proposalThreshold.
    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return GovernorSettings.proposalThreshold();
    }

    /// @dev Update the voting delay. This operation can only be performed through a governance proposal.
    /// @dev The precision is in blocks.
    function setVotingDelay(uint256 newVotingDelay) public override(GovernorSettings) onlyGovernance {
        require(newVotingDelay <= 300, "ZivoeGovernorV2::setVotingDelay newVotingDelay > 300 blocks");
        _setVotingDelay(newVotingDelay);
    }

    /// @dev Update the voting period. This operation can only be performed through a governance proposal.
    /// @dev The precision is in blocks.
    function setVotingPeriod(uint256 newVotingPeriod) public override(GovernorSettings) onlyGovernance {
        require(newVotingPeriod >= 2400, "ZivoeGovernorV2::setVotingPeriod newVotingPeriod < 2400 blocks");
        require(newVotingPeriod <= 21600, "ZivoeGovernorV2::setVotingPeriod newVotingPeriod > 21600 block");
        _setVotingPeriod(newVotingPeriod);
    }

    /// @dev Update the proposal threshold. This operation can only be performed through a governance proposal.
    function setProposalThreshold(uint256 newProposalThreshold) public override(GovernorSettings) onlyGovernance {
        require(
            newProposalThreshold <= 125000 ether, 
            "ZivoeGovernorV2::setProposalThreshold newProposalThreshold > 125000 ether"
        );
        _setProposalThreshold(newProposalThreshold);
    }

    /// @dev Changes the quorum numerator.
    function updateQuorumNumerator(uint256 newQuorumNumerator) public override(GovernorVotesQuorumFraction) onlyGovernance {
        require(newQuorumNumerator <= 30, "ZivoeGovernorV2::updateQuorumNumerator newQuorumNumerator > 30");
        _updateQuorumNumerator(newQuorumNumerator);
    }

    /// @dev Utilize the ZivoeGTC contract which defines _executor as TimelockController.
    function _executor() internal view override(Governor, ZivoeGTC) returns (address) {
        return ZivoeGTC._executor();
    }

    /// @dev Utilize the ZivoeGTC contract, defines supportsInterface at highest-level and handles inherited contracts.
    function supportsInterface(bytes4 interfaceId) public view override(Governor, ZivoeGTC) returns (bool) {
        return ZivoeGTC.supportsInterface(interfaceId);
    }

    /// @dev Utilize the ZivoeGTC contract which supports TimelockController.
    function _execute(
        uint256 proposalId, 
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    ) internal override(Governor, ZivoeGTC) {
        ZivoeGTC._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Utilize the ZivoeGTC contract which supports TimelockController.
    function _cancel(
        address[] memory targets, 
        uint256[] memory values, 
        bytes[] memory calldatas, 
        bytes32 descriptionHash
    ) internal override(Governor, ZivoeGTC) returns (uint256) {
        return ZivoeGTC._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Override voting weight from token's built in snapshot mechanism, increase by $vestZVE and $stZVE balance.
    function _getVotes(
        address account,
        uint256 blockNumber,
        bytes memory /*params*/
    ) internal view virtual override(Governor, GovernorVotes) returns (uint256) {
        return token.getPastVotes(account, blockNumber) + 
            IZivoeRewardsVesting_ZVG(IZivoeGlobals_ZVG(GBL).vestZVE()).getPastVotes(account, blockNumber) +
            IZivoeRewards_ZVG(IZivoeGlobals_ZVG(GBL).stZVE()).getPastVotes(account, blockNumber);
    }
    
}