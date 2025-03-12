// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/validators/IGovValidators.sol";

import "../../../gov/validators/GovValidators.sol";
import "../../../gov/validators/GovValidatorsToken.sol";

import "./GovValidatorsUtils.sol";

import "../../../core/Globals.sol";

library GovValidatorsExecute {
    using GovValidatorsUtils for *;

    event ChangedValidatorsBalances(address[] validators, uint256[] newBalance);

    function executeInternalProposal(IGovValidators.InternalProposal storage proposal) external {
        require(proposal.core.proposalExists(), "Validators: proposal does not exist");
        require(
            proposal.core.getProposalState() == IGovValidators.ProposalState.Succeeded,
            "Validators: not Succeeded state"
        );

        proposal.core.executed = true;

        (bool success, ) = address(this).call(proposal.data);
        require(success, "Validators: failed to execute");
    }

    function changeBalances(
        address[] memory userAddresses,
        uint256[] memory newValues
    ) external returns (uint256 validatorsCount_) {
        GovValidators govValidators = GovValidators(payable(address(this)));

        GovValidatorsToken token = govValidators.govValidatorsToken();
        validatorsCount_ = govValidators.validatorsCount();

        uint256 length = newValues.length;

        for (uint256 i = 0; i < length; i++) {
            address user = userAddresses[i];
            uint256 newBalance = newValues[i];
            uint256 balance = token.balanceOf(user);

            if (balance < newBalance) {
                token.mint(user, newBalance - balance);

                if (balance == 0) {
                    validatorsCount_++;
                }
            } else if (balance > newBalance) {
                token.burn(user, balance - newBalance);

                if (newBalance == 0) {
                    validatorsCount_--;
                }
            }
        }

        emit ChangedValidatorsBalances(userAddresses, newValues);
    }
}
