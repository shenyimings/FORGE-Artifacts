// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/// @title IPricingTable
/// @author Polytrade
interface IPricingTable {
    struct PricingItem {
        uint16 minTenure;
        uint16 maxTenure;
        uint16 maxAdvancedRatio;
        uint16 minDiscountFee;
        uint16 minFactoringFee;
        uint minAmount;
        uint maxAmount;
    }

    /**
     * @notice Add a Pricing Item to the Pricing Table
     * @dev Only Owner is authorized to add a Pricing Item
     * @param pricingId, pricingId (hex format)
     * @param minTenure, minimum tenure expressed in percentage
     * @param maxTenure, maximum tenure expressed in percentage
     * @param maxAdvancedRatio, maximum advanced ratio expressed in percentage
     * @param minDiscountRange, minimum discount range expressed in percentage
     * @param minFactoringFee, minimum Factoring fee expressed in percentage
     * @param minAmount, minimum amount
     * @param maxAmount, maximum amount
     */
    function addPricingItem(
        uint16 pricingId,
        uint16 minTenure,
        uint16 maxTenure,
        uint16 maxAdvancedRatio,
        uint16 minDiscountRange,
        uint16 minFactoringFee,
        uint minAmount,
        uint maxAmount
    ) external;

    /**
     * @notice Add a Pricing Item to the Pricing Table
     * @dev Only Owner is authorized to add a Pricing Item
     * @param pricingId, pricingId (hex format)
     * @param minTenure, minimum tenure expressed in percentage
     * @param maxTenure, maximum tenure expressed in percentage
     * @param maxAdvancedRatio, maximum advanced ratio expressed in percentage
     * @param minDiscountRange, minimum discount range expressed in percentage
     * @param minFactoringFee, minimum Factoring fee expressed in percentage
     * @param minAmount, minimum amount
     * @param maxAmount, maximum amount
     */
    function updatePricingItem(
        uint16 pricingId,
        uint16 minTenure,
        uint16 maxTenure,
        uint16 maxAdvancedRatio,
        uint16 minDiscountRange,
        uint16 minFactoringFee,
        uint minAmount,
        uint maxAmount,
        bool status
    ) external;

    /**
     * @notice Remove a Pricing Item from the Pricing Table
     * @dev Only Owner is authorized to add a Pricing Item
     * @param id, id of the pricing Item
     */
    function removePricingItem(uint16 id) external;

    /**
     * @notice Returns the pricing Item
     * @param id, id of the pricing Item
     * @return returns the PricingItem (struct)
     */
    function getPricingItem(uint16 id)
        external
        view
        returns (PricingItem memory);

    /**
     * @notice Returns if the pricing Item is valid
     * @param id, id of the pricing Item
     * @return returns boolean if pricing is valid or not
     */
    function isPricingItemValid(uint16 id) external view returns (bool);

    event NewPricingItem(uint16 id, PricingItem pricingItem);
    event UpdatedPricingItem(uint16 id, PricingItem pricingItem);
    event RemovedPricingItem(uint16 id);
}
