// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.5.17;

import "../PToken/PToken.sol";

contract PriceOracleInterface {
    /// @notice Indicator that this is a PriceOracle contract (for inspection)
    bool public constant isPriceOracle = true;

    /**
      * @notice Get the price of underlying pToken asset.
      * @param pToken The pToken
      * @return The price of pToken.underlying(). Decimals: 36 - underlyingDecimals
      */
    function getUnderlyingPrice(PToken pToken) public view returns (uint);

    /**
      * @notice Get the price of a given token
      * @param token The token. Use address(0) for native token (like ETH).
      * @param decimals Wanted decimals
      * @return The price of the token with a given decimals
      */
    function getPriceOfUnderlying(address token, uint decimals) public view returns (uint);

    /** @notice Check whether token is supported by this oracle and we've got a price for it
      * @param token The token to check
      */
    function isTokenSupported(address token) public view returns (bool);

    /** @notice Check whether pToken is supported by this oracle and we've got a price for its underlying asset
      * @param pToken The token to check
      */
    function isPTokenSupported(PToken pToken) public view returns (bool);
}
