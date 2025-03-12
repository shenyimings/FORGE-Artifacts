// Based on AAVE protocol
// SPDX-License-Identifier: GPL-3.0

// This file does not define a pragma version because it is meant to be compiled with Solang and Solang ignores
// pragma definitions, see [here](https://solang.readthedocs.io/en/latest/language/pragmas.html).

/// @title IPriceOracleGetter interface
interface IPriceOracleGetter {
    /// @dev returns the asset price in USD
    function getAssetPrice(address _asset) external returns (uint256);
}
