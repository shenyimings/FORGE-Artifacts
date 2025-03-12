// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

interface ISorbettoStrategy {
    /// @notice Period of time that we observe for price slippage
    /// @return time in seconds
    function twapDuration() external view returns (uint32);

    /// @notice Maximum deviation of time waited avarage price in ticks
    function maxTwapDeviation() external view returns (int24);

    /// @notice Tick multuplier for base range calculation
    function tickRangeMultiplier() external view returns (int24);

    /// @notice The protocol's fee denominated in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function protocolFee() external view returns (uint24);

    /// @notice The price impact percentage during swap denominated in hundredths of a bip, i.e. 1e-6
    /// @return The max price impact percentage
    function priceImpactPercentage() external view returns (uint24);
}