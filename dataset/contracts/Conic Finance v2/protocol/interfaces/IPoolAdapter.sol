// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

interface IPoolAdapter {
    /// @notice Deposit `underlyingAmount` of `underlying` into `pool`
    /// @dev This function should be written with the assumption that it will be delegate-called into
    function deposit(address pool, address underlying, uint256 underlyingAmount) external;

    /// @notice Withdraw `underlyingAmount` of `underlying` from `pool`
    /// @dev This function should be written with the assumption that it will be delegate-called into
    function withdraw(address pool, address underlying, uint256 underlyingAmount) external;

    /// @notice Returns the amount of of assets that `conicPool` holds in `pool`, in terms of USD
    function computePoolValueInUSD(
        address conicPool,
        address pool
    ) external view returns (uint256 usdAmount);

    /// @notice Returns the amount of of assets that `conicPool` holds in `pool`, in terms of underlying
    function computePoolValueInUnderlying(
        address conicPool,
        address pool,
        address underlying,
        uint256 underlyingPrice
    ) external view returns (uint256 underlyingAmount);

    /// @notice Claim earnings of `conicPool` from `pool`
    function claimEarnings(address conicPool, address pool) external;

    /// @notice Returns the LP token of a given `pool`
    function lpToken(address pool) external view returns (address);

    /// @notice Returns true if `pool` supports `asset`
    function supportsAsset(address pool, address asset) external view returns (bool);

    /// @notice Returns the amount of CRV earned by `pool` on Convex
    function getCRVEarnedOnConvex(
        address account,
        address curvePool
    ) external view returns (uint256);

    /// @notice Executes a sanity check, e.g. checking for reentrancy
    function executeSanityCheck(address pool) external;
}
