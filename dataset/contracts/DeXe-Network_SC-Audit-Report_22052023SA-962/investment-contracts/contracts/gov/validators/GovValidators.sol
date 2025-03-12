// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../interfaces/gov/validators/IGovValidators.sol";
import "../../interfaces/gov/IGovPool.sol";

import "../../libs/gov/gov-validators/GovValidatorsCreate.sol";
import "../../libs/gov/gov-validators/GovValidatorsVote.sol";
import "../../libs/gov/gov-validators/GovValidatorsExecute.sol";
import "../../libs/gov/gov-validators/GovValidatorsUtils.sol";

import "./GovValidatorsToken.sol";

contract GovValidators is IGovValidators, OwnableUpgradeable {
    using Math for uint256;
    using MathHelper for uint256;
    using GovValidatorsCreate for *;
    using GovValidatorsVote for *;
    using GovValidatorsExecute for *;
    using GovValidatorsUtils for *;

    GovValidatorsToken public govValidatorsToken;

    ProposalSettings public internalProposalSettings;

    uint256 public latestInternalProposalId;
    uint256 public validatorsCount;

    mapping(uint256 => InternalProposal) internal _internalProposals; // proposalId => info
    mapping(uint256 => ExternalProposal) internal _externalProposals; // proposalId => info

    mapping(uint256 => mapping(bool => mapping(address => mapping(bool => uint256))))
        public addressVoted; // proposalId => isInternal => user => isVoteFor => voted amount

    event ExternalProposalCreated(uint256 proposalId, uint256 quorum);
    event InternalProposalCreated(
        uint256 proposalId,
        string proposalDescription,
        uint256 quorum,
        address sender
    );

    event InternalProposalExecuted(uint256 proposalId, address executor);

    event Voted(uint256 proposalId, address sender, uint256 vote, bool isInternal, bool isVoteFor);
    event VoteCanceled(uint256 proposalId, address sender, bool isInternal);

    /// @dev Access only for addresses that have validator tokens
    modifier onlyValidator() {
        _onlyValidator();
        _;
    }

    modifier onlyThis() {
        _onlyThis();
        _;
    }

    modifier onlyThisOrGovPool() {
        _onlyThisOrGovPool();
        _;
    }

    function __GovValidators_init(
        string calldata name,
        string calldata symbol,
        ProposalSettings calldata proposalSettings,
        address[] calldata validators,
        uint256[] calldata balances
    ) external initializer {
        __Ownable_init();

        validators.validateChangeBalances(balances);
        proposalSettings.validateProposalSettings();

        govValidatorsToken = new GovValidatorsToken(name, symbol);

        internalProposalSettings = proposalSettings;

        validatorsCount = validators.changeBalances(balances);
    }

    function createInternalProposal(
        ProposalType proposalType,
        string calldata descriptionURL,
        bytes calldata data
    ) external override onlyValidator {
        ++latestInternalProposalId;

        _internalProposals.createInternalProposal(
            internalProposalSettings,
            proposalType,
            descriptionURL,
            data
        );

        emit InternalProposalCreated(
            latestInternalProposalId,
            descriptionURL,
            internalProposalSettings.quorum,
            msg.sender
        );
    }

    function createExternalProposal(
        uint256 proposalId,
        ProposalSettings calldata proposalSettings
    ) external override onlyOwner {
        _externalProposals.createExternalProposal(proposalId, proposalSettings);

        emit ExternalProposalCreated(proposalId, proposalSettings.quorum);
    }

    function voteInternalProposal(
        uint256 proposalId,
        uint256 amount,
        bool isVoteFor
    ) external override {
        _getCore(proposalId, true).vote(
            addressVoted[proposalId][true][msg.sender],
            amount,
            isVoteFor
        );

        emit Voted(proposalId, msg.sender, amount, true, isVoteFor);
    }

    function voteExternalProposal(
        uint256 proposalId,
        uint256 amount,
        bool isVoteFor
    ) external override {
        _getCore(proposalId, false).vote(
            addressVoted[proposalId][false][msg.sender],
            amount,
            isVoteFor
        );

        emit Voted(proposalId, msg.sender, amount, false, isVoteFor);
    }

    function cancelVoteInternalProposal(uint256 proposalId) external override {
        _getCore(proposalId, true).cancelVote(addressVoted[proposalId][true][msg.sender]);

        emit VoteCanceled(proposalId, msg.sender, true);
    }

    function cancelVoteExternalProposal(uint256 proposalId) external override {
        _getCore(proposalId, false).cancelVote(addressVoted[proposalId][false][msg.sender]);

        emit VoteCanceled(proposalId, msg.sender, false);
    }

    function executeInternalProposal(uint256 proposalId) external override {
        _internalProposals[proposalId].executeInternalProposal();

        emit InternalProposalExecuted(proposalId, msg.sender);
    }

    function executeExternalProposal(uint256 proposalId) external override onlyOwner {
        _externalProposals[proposalId].core.executed = true;
    }

    function changeSettings(
        uint64 duration,
        uint64 executionDelay,
        uint128 quorum
    ) external override onlyThis {
        ProposalSettings storage proposalSettings = internalProposalSettings;

        proposalSettings.duration = duration;
        proposalSettings.executionDelay = executionDelay;
        proposalSettings.quorum = quorum;
    }

    function changeBalances(
        uint256[] calldata newValues,
        address[] calldata userAddresses
    ) external override onlyThisOrGovPool {
        validatorsCount = userAddresses.changeBalances(newValues);
    }

    function monthlyWithdraw(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address destination
    ) external override onlyThis {
        IGovPool(owner()).transferCreditAmount(tokens, amounts, destination);
    }

    receive() external payable onlyThis {}

    function getExternalProposal(
        uint256 index
    ) external view override returns (ExternalProposal memory) {
        return _externalProposals[index];
    }

    function getInternalProposals(
        uint256 offset,
        uint256 limit
    ) external view override returns (InternalProposalView[] memory internalProposals) {
        uint256 to = (offset + limit).min(latestInternalProposalId).max(offset);

        internalProposals = new InternalProposalView[](to - offset);

        for (uint256 i = offset; i < to; i++) {
            internalProposals[i - offset] = InternalProposalView({
                proposal: _internalProposals[i + 1],
                proposalState: getProposalState(i + 1, true),
                requiredQuorum: getProposalRequiredQuorum(i + 1, true)
            });
        }
    }

    function getProposalState(
        uint256 proposalId,
        bool isInternal
    ) public view override returns (ProposalState) {
        if (!_proposalExists(proposalId, isInternal)) {
            return ProposalState.Undefined;
        }

        return
            isInternal
                ? _internalProposals[proposalId].core.getProposalState()
                : _externalProposals[proposalId].core.getProposalState();
    }

    function getProposalRequiredQuorum(
        uint256 proposalId,
        bool isInternal
    ) public view override returns (uint256) {
        ProposalCore storage core = _getCore(proposalId, isInternal);

        if (core.voteEnd == 0) {
            return 0;
        }

        return
            govValidatorsToken.totalSupplyAt(core.snapshotId).ratio(core.quorum, PERCENTAGE_100);
    }

    function isValidator(address user) public view override returns (bool) {
        return govValidatorsToken.balanceOf(user) > 0;
    }

    function _proposalExists(uint256 proposalId, bool isInternal) internal view returns (bool) {
        return _getCore(proposalId, isInternal).proposalExists();
    }

    function _getCore(
        uint256 proposalId,
        bool isInternal
    ) internal view returns (ProposalCore storage) {
        return
            isInternal ? _internalProposals[proposalId].core : _externalProposals[proposalId].core;
    }

    function _onlyValidator() internal view {
        require(isValidator(msg.sender), "Validators: caller is not the validator");
    }

    function _onlyThis() internal view {
        require(address(this) == msg.sender, "Validators: not this contract");
    }

    function _onlyThisOrGovPool() internal view {
        require(
            address(this) == msg.sender || owner() == msg.sender,
            "Validators: not this nor GovPool contract"
        );
    }
}
