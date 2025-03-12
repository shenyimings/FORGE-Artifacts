// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IPricingTable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Pricing Table
/// @author Polytrade
contract PricingTable is IPricingTable, Ownable {
    mapping(uint16 => PricingItem) private _pricingItems;
    mapping(uint16 => bool) private _pricingStatus;

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
    ) external onlyOwner {
        require(!_pricingStatus[pricingId], "Already exists, please update");
        PricingItem memory _pricingItem;

        _pricingItem.minTenure = minTenure;
        _pricingItem.maxTenure = maxTenure;
        _pricingItem.minAmount = minAmount;
        _pricingItem.maxAmount = maxAmount;
        _pricingItem.maxAdvancedRatio = maxAdvancedRatio;
        _pricingItem.minDiscountFee = minDiscountRange;
        _pricingItem.minFactoringFee = minFactoringFee;
        _pricingItems[pricingId] = _pricingItem;
        _pricingStatus[pricingId] = true;
        emit NewPricingItem(pricingId, _pricingItems[pricingId]);
    }

    /**
     * @notice Update an existing Pricing Item
     * @dev Only Owner is authorized to update a Pricing Item
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
    ) external onlyOwner {
        require(_pricingStatus[pricingId], "Invalid Pricing Item");

        _pricingItems[pricingId].minTenure = minTenure;
        _pricingItems[pricingId].maxTenure = maxTenure;
        _pricingItems[pricingId].minAmount = minAmount;
        _pricingItems[pricingId].maxAmount = maxAmount;
        _pricingItems[pricingId].maxAdvancedRatio = maxAdvancedRatio;
        _pricingItems[pricingId].minDiscountFee = minDiscountRange;
        _pricingItems[pricingId].minFactoringFee = minFactoringFee;
        _pricingStatus[pricingId] = status;
        emit UpdatedPricingItem(pricingId, _pricingItems[pricingId]);
    }

    /**
     * @notice Remove a Pricing Item from the Pricing Table
     * @dev Only Owner is authorized to add a Pricing Item
     * @param id, id of the pricing Item
     */
    function removePricingItem(uint16 id) external onlyOwner {
        delete _pricingItems[id];
        _pricingStatus[id] = false;
        emit RemovedPricingItem(id);
    }

    /**
     * @notice Returns the pricing Item
     * @param id, id of the pricing Item
     * @return returns the PricingItem (struct)
     */
    function getPricingItem(uint16 id)
        external
        view
        override
        returns (PricingItem memory)
    {
        return _pricingItems[id];
    }

    /**
     * @notice Returns if the pricing Item is valid
     * @param id, id of the pricing Item
     * @return returns boolean if pricing is valid or not
     */
    function isPricingItemValid(uint16 id)
        external
        view
        override
        returns (bool)
    {
        return _pricingStatus[id];
    }
}
