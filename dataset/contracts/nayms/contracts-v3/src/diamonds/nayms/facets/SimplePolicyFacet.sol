// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { Modifiers } from "../Modifiers.sol";
import { Entity, SimplePolicy, SimplePolicyInfo, PolicyCommissionsBasisPoints } from "../AppStorage.sol";
import { LibObject } from "../libs/LibObject.sol";
import { LibHelpers } from "../libs/LibHelpers.sol";
import { LibSimplePolicy } from "../libs/LibSimplePolicy.sol";
import { LibFeeRouter } from "../libs/LibFeeRouter.sol";

/**
 * @title Simple Policies
 * @notice Facet for working with Simple Policies
 * @dev Simple Policy facet
 */
contract SimplePolicyFacet is Modifiers {
    /**
     * @dev Pay a premium of `_amount` on simple policy
     * @param _policyId Id of the simple policy
     * @param _amount Amount of the premium
     */
    function paySimplePremium(bytes32 _policyId, uint256 _amount) external assertPolicyHandler(_policyId) {
        bytes32 senderId = LibHelpers._getIdForAddress(msg.sender);
        bytes32 payerEntityId = LibObject._getParent(senderId);

        LibSimplePolicy._payPremium(payerEntityId, _policyId, _amount);
    }

    /**
     * @dev Pay a claim of `_amount` for simple policy
     * @param _claimId Id of the simple policy claim
     * @param _policyId Id of the simple policy
     * @param _insuredId Id of the insured party
     * @param _amount Amount of the claim
     */
    function paySimpleClaim(
        bytes32 _claimId,
        bytes32 _policyId,
        bytes32 _insuredId,
        uint256 _amount
    ) external assertSysMgr {
        LibSimplePolicy._payClaim(_claimId, _policyId, _insuredId, _amount);
    }

    /**
     * @dev Get simple policy info
     * @param _policyId Id of the simple policy
     * @return Simple policy metadata
     */
    function getSimplePolicyInfo(bytes32 _policyId) external view returns (SimplePolicyInfo memory) {
        SimplePolicy memory p = LibSimplePolicy._getSimplePolicyInfo(_policyId);
        return
            SimplePolicyInfo({
                startDate: p.startDate,
                maturationDate: p.maturationDate,
                asset: p.asset,
                limit: p.limit,
                fundsLocked: p.fundsLocked,
                cancelled: p.cancelled,
                claimsPaid: p.claimsPaid,
                premiumsPaid: p.premiumsPaid
            });
    }

    function getPremiumCommissionBasisPoints() external view returns (PolicyCommissionsBasisPoints memory bp) {
        bp = LibFeeRouter._getPremiumCommissionBasisPoints();
    }

    /**
     * @dev Check and update simple policy state
     * @param _policyId Id of the simple policy
     */
    function checkAndUpdateSimplePolicyState(bytes32 _policyId) external {
        LibSimplePolicy._checkAndUpdateState(_policyId);
    }

    /**
     * @dev Cancel a simple policy
     * @param _policyId Id of the simple policy
     */
    function cancelSimplePolicy(bytes32 _policyId) external assertSysMgr {
        LibSimplePolicy._cancel(_policyId);
    }
}
