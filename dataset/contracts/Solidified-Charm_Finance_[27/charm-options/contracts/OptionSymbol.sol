// SPDX-License-Identifier: MIT
// Adapted from: https://github.com/opynfinance/GammaProtocol/blob/master/contracts/Otoken.sol

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./libraries/BokkyPooBahsDateTimeLibrary.sol";

contract OptionSymbol {
    using SafeMath for uint256;

    uint256 private constant STRIKE_PRICE_SCALE = 1e18;
    uint256 private constant STRIKE_PRICE_DIGITS = 18;

    // example symbol: Charm LP ETH 04DEC2020 C
    function getMarketSymbol(
        string memory underlying,
        uint256 expiryTime,
        bool isPut
    ) public pure returns (string memory) {
        (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(expiryTime);
        (string memory monthSymbol, ) = _getMonth(month);

        string memory suffix = isPut ? "P" : "C";

        return
            string(
                abi.encodePacked(
                    "Charm LP ",
                    underlying,
                    " ",
                    _uintTo2Chars(day),
                    monthSymbol,
                    Strings.toString(year),
                    " ",
                    suffix
                )
            );
    }

    // example symbol: Charm ETH 04DEC2020 500 C
    function getOptionSymbol(
        string memory underlying,
        uint256 strikePrice,
        uint256 expiryTime,
        bool isPut,
        bool isLong
    ) public pure returns (string memory) {
        string memory displayStrikePrice = _getDisplayedStrikePrice(strikePrice);

        (uint256 year, uint256 month, uint256 day) = BokkyPooBahsDateTimeLibrary.timestampToDate(expiryTime);
        (string memory monthSymbol, ) = _getMonth(month);

        string memory suffix = isPut ? (isLong ? "P" : "SP") : (isLong ? "C" : "SC");

        return
            string(
                abi.encodePacked(
                    "Charm ",
                    underlying,
                    " ",
                    _uintTo2Chars(day),
                    monthSymbol,
                    Strings.toString(year),
                    " ",
                    displayStrikePrice,
                    " ",
                    suffix
                )
            );
    }

    /**
     * @dev convert strike price scaled by 1e8 to human readable number string
     * @param _strikePrice strike price scaled by 1e8
     * @return strike price string
     */
    function _getDisplayedStrikePrice(uint256 _strikePrice) internal pure returns (string memory) {
        uint256 remainder = _strikePrice.mod(STRIKE_PRICE_SCALE);
        uint256 quotient = _strikePrice.div(STRIKE_PRICE_SCALE);
        string memory quotientStr = Strings.toString(quotient);

        if (remainder == 0) return quotientStr;

        uint256 trailingZeroes = 0;
        while (remainder.mod(10) == 0) {
            remainder = remainder / 10;
            trailingZeroes += 1;
        }

        // pad the number with "1 + starting zeroes"
        remainder += 10**(STRIKE_PRICE_DIGITS - trailingZeroes);

        string memory tmpStr = Strings.toString(remainder);
        tmpStr = _slice(tmpStr, 1, 1 + STRIKE_PRICE_DIGITS - trailingZeroes);

        string memory completeStr = string(abi.encodePacked(quotientStr, ".", tmpStr));
        return completeStr;
    }

    /**
     * @dev return a representation of a number using 2 characters, adds a leading 0 if one digit, uses two trailing digits if a 3 digit number
     * @return 2 characters that corresponds to a number
     */
    function _uintTo2Chars(uint256 number) internal pure returns (string memory) {
        if (number > 99) number = number % 100;
        string memory str = Strings.toString(number);
        if (number < 10) {
            return string(abi.encodePacked("0", str));
        }
        return str;
    }

    /**
     * @dev cut string s into s[start:end]
     * @param _s the string to cut
     * @param _start the starting index
     * @param _end the ending index (excluded in the substring)
     */
    function _slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure returns (string memory) {
        bytes memory a = new bytes(_end - _start);
        for (uint256 i = 0; i < _end - _start; i++) {
            a[i] = bytes(_s)[_start + i];
        }
        return string(a);
    }

    /**
     * @dev return string representation of a month
     * @return shortString a 3 character representation of a month (ex: SEP, DEC, etc)
     * @return longString a full length string of a month (ex: September, December, etc)
     */
    function _getMonth(uint256 _month) internal pure returns (string memory shortString, string memory longString) {
        if (_month == 1) {
            return ("JAN", "January");
        } else if (_month == 2) {
            return ("FEB", "February");
        } else if (_month == 3) {
            return ("MAR", "March");
        } else if (_month == 4) {
            return ("APR", "April");
        } else if (_month == 5) {
            return ("MAY", "May");
        } else if (_month == 6) {
            return ("JUN", "June");
        } else if (_month == 7) {
            return ("JUL", "July");
        } else if (_month == 8) {
            return ("AUG", "August");
        } else if (_month == 9) {
            return ("SEP", "September");
        } else if (_month == 10) {
            return ("OCT", "October");
        } else if (_month == 11) {
            return ("NOV", "November");
        } else {
            return ("DEC", "December");
        }
    }
}
