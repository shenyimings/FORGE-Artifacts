// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;


/**
 * @dev **`CurvePriceConfig` struct properties:**
 *
 * - `maxPrice` (uint256): Maximum price for a domain returned at <= `baseLength`
 * - `minPrice` (uint256): Minimum price for a domain returned at > `maxLength`
 * - `maxLength` (uint256): Maximum length of a domain name. If the name is longer - we return the `minPrice`
 * - `baseLength` (uint256): Base length of a domain name. If the name is shorter or equal - we return the `maxPrice`
 * - `precisionMultiplier` (uint256): The precision multiplier of the price. This multiplier
 * should be picked based on the number of token decimals to calculate properly.
 * e.g. if we use a token with 18 decimals, and want precision of 2,
 * our precision multiplier will be equal 10^18 - 10^2 = 10^16
 */
interface ICurvePriceConfig {
/**
 * @notice Struct for each configurable variable for price calculations.
     * Does NOT include variables for calcs of registration fees.
     */
    struct CurvePriceConfig {
        /**
         * @notice Maximum price for a domain returned at <= `baseLength`
        */
        uint256 maxPrice;
        /**
         * @notice Minimum price for a domain returned at > `maxLength`
         */
        uint256 minPrice;
        /**
         * @notice Maximum length of a domain name. If the name is longer than this
         * value we return the `minPrice`
         */
        uint256 maxLength;
        /**
         * @notice Base length of a domain name. If the name is less than or equal to
         * this value we return the `maxPrice`
         */
        uint256 baseLength;
        /**
         * @notice The precision multiplier of the price. This multiplier
         * should be picked based on the number of token decimals to calculate properly.
         * e.g. if we use a token with 18 decimals, and want precision of 2,
         * our precision multiplier will be equal 10^18 - 10^2 = 10^16
         */
        uint256 precisionMultiplier;
        /**
         * @notice The registration fee value in percentage as basis points (parts per 10,000)
         *  so the 2% value would be represented as 200.
         *  See [getRegistrationFee](#getregistrationfee) for the actual fee calc process.
         */
        uint256 feePercentage;

        /**
         * @notice A boolean value signifying the fact that this whole config has been set.
         * This value is checked by other contracts to avoid giving out free domains for users who
         * haven't yet managed to set their config.
        */
        bool isSet;
    }
}
