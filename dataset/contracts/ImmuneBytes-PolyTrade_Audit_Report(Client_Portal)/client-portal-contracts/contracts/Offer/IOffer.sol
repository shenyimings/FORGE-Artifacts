// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/// Tenure is not within minimum and maximum authorized
/// @param tenure, actual tenure
/// @param minTenure, minimum tenure
/// @param maxTenure, maximum tenure
error InvalidTenure(uint16 tenure, uint16 minTenure, uint16 maxTenure);

/// AdvanceFee is higher than the maxAdvancedRatio
/// @param advanceFee, actual advanceFee
/// @param maxAdvancedRatio, maximum advanced ratio
error InvalidAdvanceFee(uint16 advanceFee, uint16 maxAdvancedRatio);

/// DiscountFee is lower than the minDiscountFee
/// @param discountFee, actual discountFee
/// @param minDiscountFee, minimum discount fee
error InvalidDiscountFee(uint16 discountFee, uint16 minDiscountFee);

/// FactoringFee is lower than the minDiscountFee
/// @param factoringFee, actual factoringFee
/// @param minFactoringFee, minimum factoring fee
error InvalidFactoringFee(uint16 factoringFee, uint16 minFactoringFee);

/// InvoiceAmount is not within minimum and maximum authorized
/// @param invoiceAmount, actual invoice amount
/// @param minAmount, minimum invoice amount
/// @param maxAmount, maximum invoice amount
error InvalidInvoiceAmount(uint invoiceAmount, uint minAmount, uint maxAmount);

/// Available Amount is higher than Invoice Amount
/// @param availableAmount, actual available amount
/// @param invoiceAmount, actual invoice amount
error InvalidAvailableAmount(uint availableAmount, uint invoiceAmount);

/// @title IOffer
/// @author Polytrade
interface IOffer {
    struct OfferItem {
        uint advancedAmount;
        uint reserve;
        uint64 disbursingAdvanceDate;
        OfferParams params;
        OfferRefunded refunded;
    }

    struct OfferParams {
        uint8 gracePeriod;
        uint16 tenure;
        uint16 factoringFee;
        uint16 discountFee;
        uint16 advanceFee;
        address stableAddress;
        uint invoiceAmount;
        uint availableAmount;
    }

    struct OfferRefunded {
        uint16 lateFee;
        uint64 dueDate;
        uint24 numberOfLateDays;
        uint totalCalculatedFees;
        uint netAmount;
        uint rewards;
    }

    /**
     * @dev Emitted when new offer is created
     */
    event OfferCreated(uint indexed offerId, uint16 pricingId);

    /**
     * @dev Emitted when Reserve is refunded
     */
    event ReserveRefunded(uint indexed offerId, uint refundedAmount);

    /**
     * @dev Emitted when PricingTable Address is updated
     */
    event NewPricingTableContract(
        address oldPricingTableAddress,
        address newPricingTableAddress
    );

    /**
     * @dev Emitted when PriceFeed Address is updated
     */
    event NewPriceFeedContract(
        address oldPriceFeedAddress,
        address newPriceFeedAddress
    );

    /**
     * @dev Emitted when Treasury Address is updated
     */
    event NewTreasuryAddress(
        address oldTreasuryAddress,
        address newTreasuryAddress
    );

    /**
     * @dev Emitted when LenderPool Address is updated
     */
    event NewLenderPoolAddress(
        address oldLenderPoolAddress,
        address newLenderPoolAddress
    );

    /**
     * @dev Emitted when Oracle usage is activated or deactivated
     */
    event OracleUsageUpdated(bool status);
}
