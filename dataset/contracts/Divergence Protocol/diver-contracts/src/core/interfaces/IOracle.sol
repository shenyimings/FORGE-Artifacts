// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/// @title Get external price by oracle
/// @notice Collects and updates underlying asset prices used for settling
/// options.
/// It retrieves asset prices and supplies them to all contracts that use them.
interface IOracle {
    function price(string memory symbol) external view returns (uint256);

    function historyPrice(string memory symbol, uint256 ts) external view returns (uint256);

    /// @notice Helper for updating prices retrieved from an external oracle
    /// @param symbol The asset symbol for which to retrieve price feed
    /// @param ts Timestamp for the asset price
    /// @return price_ The retrieved price
    function updatePriceByExternal(string memory symbol, uint256 ts) external returns (uint256 price_);
}
