// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

interface CloberPriceBook {
    /**
     * @notice Returns the biggest price book index supported.
     * @return The biggest price book index supported.
     */
    function maxPriceIndex() external view returns (uint16);

    /**
     * @notice Returns the upper bound of prices supported.
     * @dev The price upper bound can be greater than `indexToPrice(maxPriceIndex())`.
     * @return The the upper bound of prices supported.
     */
    function priceUpperBound() external view returns (uint256);

    /**
     * @notice Converts the price index into the actual price.
     * @param priceIndex The price book index.
     * @return price The actual price.
     */
    function indexToPrice(uint16 priceIndex) external view returns (uint256);

    /**
     * @notice Returns the price book index closest to the provided price.
     * @param price Provided price.
     * @param roundingUp Determines whether to round up or down.
     * @return index The price book index.
     * @return correctedPrice The actual price for the price book index.
     */
    function priceToIndex(uint256 price, bool roundingUp) external view returns (uint16 index, uint256 correctedPrice);
}
