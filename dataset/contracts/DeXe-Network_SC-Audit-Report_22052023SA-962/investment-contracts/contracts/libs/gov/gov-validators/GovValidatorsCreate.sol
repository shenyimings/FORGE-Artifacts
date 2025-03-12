// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/validators/IGovValidators.sol";

import "../../../gov/validators/GovValidators.sol";
import "../../../gov/validators/GovValidatorsToken.sol";

import "./GovValidatorsUtils.sol";

import "../../../core/Globals.sol";

library GovValidatorsCreate {
    using GovValidatorsUtils for *;

    function createInternalProposal(
        mapping(uint256 => IGovValidators.InternalProposal) storage internalProposals,
        IGovValidators.ProposalSettings storage internalSettings,
        IGovValidators.ProposalType proposalType,
        string calldata descriptionURL,
        bytes calldata data
    ) external {
        _validateInternalProposal(proposalType, data);

        GovValidatorsToken token = GovValidators(payable(address(this))).govValidatorsToken();
        uint256 latestProposalId = GovValidators(payable(address(this)))
            .latestInternalProposalId();

        internalProposals[latestProposalId] = IGovValidators.InternalProposal({
            proposalType: proposalType,
            core: IGovValidators.ProposalCore({
                voteEnd: uint64(block.timestamp + internalSettings.duration),
                executeAfter: internalSettings.executionDelay,
                executed: false,
                quorum: internalSettings.quorum,
                votesFor: 0,
                votesAgainst: 0,
                snapshotId: uint56(token.snapshot())
            }),
            descriptionURL: descriptionURL,
            data: data
        });
    }

    function createExternalProposal(
        mapping(uint256 => IGovValidators.ExternalProposal) storage externalProposals,
        uint256 proposalId,
        IGovValidators.ProposalSettings calldata proposalSettings
    ) external {
        require(
            externalProposals[proposalId].core.voteEnd == 0,
            "Validators: proposal already exists"
        );

        proposalSettings.validateProposalSettings();

        GovValidatorsToken token = GovValidators(payable(address(this))).govValidatorsToken();

        externalProposals[proposalId] = IGovValidators.ExternalProposal({
            core: IGovValidators.ProposalCore({
                voteEnd: uint64(block.timestamp + proposalSettings.duration),
                executed: false,
                quorum: proposalSettings.quorum,
                executeAfter: proposalSettings.executionDelay,
                votesFor: 0,
                votesAgainst: 0,
                snapshotId: uint56(token.snapshot())
            })
        });
    }

    function _validateInternalProposal(
        IGovValidators.ProposalType proposalType,
        bytes calldata data
    ) internal pure {
        if (proposalType == IGovValidators.ProposalType.OffchainProposal) {
            require(data.length == 0, "Validators: offchain proposal should not have data");
            return;
        }

        bytes4 selector = bytes4(data);
        bytes calldata packedData = data[4:];

        if (proposalType == IGovValidators.ProposalType.ChangeBalances) {
            require(
                selector == IGovValidators.changeBalances.selector,
                "Validators: not ChangeBalances function"
            );
            (uint256[] memory newValues, address[] memory users) = _getBalanceInfoFromData(
                packedData
            );

            users.validateChangeBalances(newValues);
        } else if (proposalType == IGovValidators.ProposalType.ChangeSettings) {
            require(
                selector == IGovValidators.changeSettings.selector,
                "Validators: not ChangeSettings function"
            );
            (
                uint64 duration,
                uint64 executionDelay,
                uint128 quorum
            ) = _getValidatorSettingsFromData(packedData);

            IGovValidators.ProposalSettings memory proposalSettings = IGovValidators
                .ProposalSettings({
                    duration: duration,
                    executionDelay: executionDelay,
                    quorum: quorum
                });

            proposalSettings.validateProposalSettings();
        } else {
            require(
                selector == IGovValidators.monthlyWithdraw.selector,
                "Validators: not MonthlyWithdraw function"
            );
            (
                address[] memory tokens,
                uint256[] memory amounts,
                address destination
            ) = _getCreditInfoFromData(packedData);

            _validateMonthlyWithdraw(tokens, amounts, destination);
        }
    }

    function _validateMonthlyWithdraw(
        address[] memory tokens,
        uint256[] memory amounts,
        address destination
    ) internal pure {
        uint256 tokensLength = tokens.length;

        require(amounts.length == tokensLength, "Validators: invalid array length");

        for (uint256 i = 0; i < tokensLength; i++) {
            require(tokens[i] != address(0), "Validators: address of token cannot be zero");
        }

        require(destination != address(0), "Validators: destination address cannot be zero");
    }

    function _getValidatorSettingsFromData(
        bytes memory _data
    ) internal pure returns (uint64 duration, uint64 executionDelay, uint128 quorum) {
        (duration, executionDelay, quorum) = abi.decode(_data, (uint64, uint64, uint128));
    }

    function _getBalanceInfoFromData(
        bytes memory _data
    ) internal pure returns (uint256[] memory newValues, address[] memory userAddresses) {
        (newValues, userAddresses) = abi.decode(_data, (uint256[], address[]));
    }

    function _getCreditInfoFromData(
        bytes memory _data
    )
        internal
        pure
        returns (address[] memory tokens, uint256[] memory amounts, address destination)
    {
        (tokens, amounts, destination) = abi.decode(_data, (address[], uint256[], address));
    }
}
