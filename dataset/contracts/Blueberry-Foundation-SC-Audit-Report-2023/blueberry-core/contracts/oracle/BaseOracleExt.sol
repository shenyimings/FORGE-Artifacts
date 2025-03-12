// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "../utils/BlueBerryConst.sol" as Constants;

abstract contract BaseOracleExt {
    /**
     * @notice Internal function to validate deviations of 2 given prices
     * @param price0 First price to validate, base 1e18
     * @param price1 Second price to validate, base 1e18
     * @param maxPriceDeviation Max price deviation of 2 prices, base 10000
     */
    function _isValidPrices(
        uint256 price0,
        uint256 price1,
        uint256 maxPriceDeviation
    ) internal pure returns (bool) {
        uint256 maxPrice = price0 > price1 ? price0 : price1;
        uint256 minPrice = price0 > price1 ? price1 : price0;
        return
            (((maxPrice - minPrice) * Constants.DENOMINATOR) / maxPrice) <=
            maxPriceDeviation;
    }
}
