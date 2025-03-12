// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../tokens/P00lsTokenCreator.sol";
import "../tokens/P00lsTokenXCreator.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsDAO is
    Initializable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorTimelockControlUpgradeable,
    UUPSUpgradeable
{
    IP00lsTokenCreator public  token;
    uint256            private _quorum;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor()
        initializer()
    {}

    function initialize(IP00lsTokenCreator __token, TimelockControllerUpgradeable __timelock)
        external
        initializer()
    {
        __Governor_init("p00lsDAO");
        __GovernorSettings_init(1, 40320, 0); // initialVotingDelay = 1 block, initialVotingPeriod = ~1 week, initialProposalThreshold = 0
        __GovernorCountingSimple_init();
        __GovernorTimelockControl_init(__timelock);

        token = __token;
        _quorum = 1;
    }

    function clock() public view override returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    function CLOCK_MODE() public view override returns (string memory) {
        require(clock() == block.number, "Votes: broken clock mode");
        return "mode=blocknumber&from=default";
    }

    function _getVotes(address account, uint256 blockNumber, bytes memory /* params */)
        internal
        view
        override
        returns (uint256)
    {
        IP00lsTokenCreator  _token  = token;
        IP00lsTokenXCreator _xtoken = _token.xCreatorToken();
        uint256             votes   = _token.getPastVotes(account, blockNumber);
        uint256             xvotes  = _xtoken.convertToAssetsAtBlock(_xtoken.getPastVotes(account, blockNumber), blockNumber);
        return votes + xvotes;
    }

    function setQuorum(uint256 newQuorum)
        public
        onlyGovernance()
    {
        _quorum = newQuorum;
    }

    function quorum(uint256)
        public
        view
        override
        returns (uint256)
    {
        return _quorum;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyGovernance()
    {}

    // The following functions are overrides required by Solidity.

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalThreshold()
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(GovernorUpgradeable, IGovernorUpgradeable)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
