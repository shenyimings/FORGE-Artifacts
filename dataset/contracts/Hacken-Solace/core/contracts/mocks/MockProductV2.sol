// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.6;

import "../products/SolaceMarketProduct.sol";

/**
 * @title MockProductV2
 * @author solace.fi
 * @notice Mock product for testing purposes.
 */
contract MockProductV2 is SolaceMarketProduct {

    uint24 private _price;

    function setPrice(uint24 price_) external {
        _price = price_;
    }

    /**
     * @notice Sets a policy's expiration block.
     * @param policyID The policy ID to set expiration for.
     * @param expirationBlock The new expiration block for the policy.
     */
    function setPolicyExpiration(uint256 policyID, uint40 expirationBlock) external {
        ( , , uint256 coverLimit, , uint24 purchasePrice, bytes memory positionDescription, address riskStrategy) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        IPolicyManager(_registry.get("policyManager")).setPolicyInfo(policyID, coverLimit, expirationBlock, purchasePrice, positionDescription, riskStrategy);
    }

    /**
     * @notice Purchases and mints a policy on the behalf of the policyholder.
     * User will need to pay **USD**.
     * @param policyholder Holder of the position to cover.
     * @param coverLimit The value to cover in **USD**. Will only cover up to the appraised value.
     * @param blocks The length (in blocks) for policy.
     * @param positionDescription The byte encoded description of the covered position(s).
     * @param riskStrategy The risk strategy of the covered product.
     * @return policyID The ID of newly created policy.
     */
    function _buyPolicy(address policyholder, uint256 coverLimit,  uint40 blocks, bytes calldata positionDescription, address riskStrategy) external payable nonReentrant returns (uint256 policyID) {
        // bypasses some important checks in BaseProduct
        // create the policy
        uint40 expirationBlock = uint40(block.number + blocks);
        policyID = IPolicyManager(_registry.get("policyManager")).createPolicy(policyholder, coverLimit, expirationBlock, _price, positionDescription, riskStrategy);

        // update local book-keeping variables
        _activeCoverLimit += coverLimit;
        _activeCoverLimitPerStrategy[riskStrategy] += coverLimit;

        emit PolicyCreated(policyID);

        return policyID;
    }
}