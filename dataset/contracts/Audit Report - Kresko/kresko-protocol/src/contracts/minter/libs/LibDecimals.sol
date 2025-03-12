// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;
import {ms} from "../MinterStorage.sol";

/**
 * @title Library for Kresko specific decimals
 */
library LibDecimals {
    /**
     * @notice For a given collateral asset and amount, returns a wad represenatation.
     * @dev If the collateral asset has decimals other than 18, the amount is scaled appropriately.
     *   If decimals > 18, there may be a loss of precision.
     * @param _decimals The collateral asset's number of decimals
     * @param _amount The amount of the collateral asset.
     * @return A fp of amount scaled according to the collateral asset's decimals.
     */
    function toWad(uint256 _decimals, uint256 _amount) internal pure returns (uint256) {
        // Initially, use the amount as the raw value for the fixed point.
        // which internally uses 18 decimals.
        // Most collateral assets will have 18 decimals.

        // Handle cases where the collateral asset's decimal amount is not 18.
        if (_decimals < 18) {
            // If the decimals are less than 18, multiply the amount
            // to get the correct wad value.
            // E.g. 1 full token of a 17 decimal token will  cause the
            // initial setting of amount to be 0.1, so we multiply
            // by 10 ** (18 - 17) = 10 to get it to 0.1 * 10 = 1.
            return _amount * (10 ** (18 - _decimals));
        } else if (_decimals > 18) {
            // If the decimals are greater than 18, divide the amount
            // to get the correct fixed point value.
            // Note because wad numbers are 18 decimals, this results
            // in loss of precision. E.g. if the collateral asset has 19
            // decimals and the deposit amount is only 1 uint, this will divide
            // 1 by 10 ** (19 - 18), resulting in 1 / 10 = 0
            return _amount / (10 ** (_decimals - 18));
        }
        return _amount;
    }

    /**
     * @notice For a given collateral asset and wad amount, returns the collateral amount.
     * @dev If the collateral asset has decimals other than 18, the amount is scaled appropriately.
     *   If decimals < 18, there may be a loss of precision.
     * @param _decimals The collateral asset's number of decimals
     * @param _wadAmount The wad amount of the collateral asset.
     * @return An amount that is compatible with the collateral asset's decimals.
     */
    function fromWad(uint256 _decimals, uint256 _wadAmount) internal pure returns (uint256) {
        // Initially, use the rawValue, which internally uses 18 decimals.
        // Most collateral assets will have 18 decimals.
        // Handle cases where the collateral asset's decimal amount is not 18.
        if (_decimals < 18) {
            // If the decimals are less than 18, divide the depositAmount
            // to get the correct collateral amount.
            // E.g. 1 full token will result in amount being 1e18 at this point,
            // so if the token has 17 decimals, divide by 10 ** (18 - 17) = 10
            // to get a value of 1e17.
            // This may result in a loss of precision.
            return _wadAmount / (10 ** (18 - _decimals));
        } else if (_decimals > 18) {
            // If the decimals are greater than 18, multiply the depositAmount
            // to get the correct fixed point value.
            // E.g. 1 full token will result in amount being 1e18 at this point,
            // so if the token has 19 decimals, multiply by 10 ** (19 - 18) = 10
            // to get a value of 1e19.
            return _wadAmount * (10 ** (_decimals - 18));
        }
        return _wadAmount;
    }

    /**
     * @notice Divides an uint256 @param _value with @param _priceWithOracleDecimals
     * @param _value Left side value of the division
     * @param wadValue result with 18 decimals
     */
    function divByPrice(uint256 _value, uint256 _priceWithOracleDecimals) internal view returns (uint256 wadValue) {
        uint8 oracleDecimals = ms().extOracleDecimals;
        if (oracleDecimals >= 18) return _priceWithOracleDecimals;
        return (_value / _priceWithOracleDecimals) * 10 ** (oracleDecimals);
    }

    /**
     * @notice Converts an uint256 with extOracleDecimals into a number with 18 decimals
     * @param _wadPrice value with extOracleDecimals
     */
    function fromWadPriceToUint(uint256 _wadPrice) internal view returns (uint256 priceWithOracleDecimals) {
        uint8 oracleDecimals = ms().extOracleDecimals;
        if (oracleDecimals == 18) return _wadPrice;
        return _wadPrice / 10 ** (18 - oracleDecimals);
    }

    /**
     * @notice Converts an uint256 with extOracleDecimals into a number with 18 decimals
     * @param _priceWithOracleDecimals value with extOracleDecimals
     * @return wadPrice with 18 decimals
     */
    function oraclePriceToWad(uint256 _priceWithOracleDecimals) internal view returns (uint256) {
        uint8 oracleDecimals = ms().extOracleDecimals;
        if (oracleDecimals == 18) {
            return _priceWithOracleDecimals;
        }
        return _priceWithOracleDecimals * 10 ** (18 - oracleDecimals);
    }

    /**
     * @notice Converts an int256 with extOracleDecimals into a number with 18 decimals
     * @param _priceWithOracleDecimals value with extOracleDecimals
     * @return wadPrice price with 18 decimals
     */
    function oraclePriceToWad(int256 _priceWithOracleDecimals) internal view returns (uint256) {
        uint8 oracleDecimals = ms().extOracleDecimals;
        if (oracleDecimals >= 18) return uint256(_priceWithOracleDecimals);
        return uint256(_priceWithOracleDecimals) * 10 ** (18 - oracleDecimals);
    }
}
