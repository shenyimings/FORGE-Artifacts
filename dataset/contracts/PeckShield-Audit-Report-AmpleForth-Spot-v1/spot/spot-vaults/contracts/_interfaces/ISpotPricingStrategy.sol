// SPDX-License-Identifier: BUSL-1.1

/**
 * @title ISpotPricingStrategy
 *
 * @notice Pricing strategy adapter for a BillBroker vault
 *         which accepts Perp and USDC tokens.
 *
 */
// solhint-disable-next-line compiler-version
interface ISpotPricingStrategy {
    /// @return Number of decimals representing the prices returned.
    function decimals() external pure returns (uint8);

    /// @return price The price of USD tokens.
    /// @return isValid True if the returned price is valid.
    function usdPrice() external returns (uint256 price, bool isValid);

    /// @return price The price of perp tokens.
    /// @return isValid True if the returned price is valid.
    function perpPrice() external returns (uint256 price, bool isValid);
}
