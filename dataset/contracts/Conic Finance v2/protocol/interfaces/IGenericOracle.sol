// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./IOracle.sol";

interface IGenericOracle is IOracle {
    /// @notice converts the price of an LP token to the given underlying
    function curveLpToUnderlying(
        address curveLpToken,
        address underlying,
        uint256 curveLpAmount
    ) external view returns (uint256);

    /// @notice same as above but avoids fetching the underlying price again
    function curveLpToUnderlying(
        address curveLpToken,
        address underlying,
        uint256 curveLpAmount,
        uint256 underlyingPrice
    ) external view returns (uint256);

    /// @notice converts the price an underlying asset to a given Curve LP token
    function underlyingToCurveLp(
        address underlying,
        address curveLpToken,
        uint256 underlyingAmount
    ) external view returns (uint256);
}
