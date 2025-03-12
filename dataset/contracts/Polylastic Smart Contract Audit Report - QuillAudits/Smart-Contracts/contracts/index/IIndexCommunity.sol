//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

interface IIndexCommunity {
    /// @notice Initialization of the main parameters
    /// @param adminDAO the address that has the right to call functions with the "DAO_ADMIN_ROLE" role
    /// @param admin the address that has the right to call functions with the "ADMIN_ROLE" role
    /// @param acceptToken the token in which the payment is accepted
    /// @param adapter adapter DEX
    /// @param startPrice initial index price
    /// @param rebalancePeriod the time after which rebalancing occurs (seconds)
    /// @param newAssets array with asset addresses
    /// @param tresuare a commission will be sent to this address
    /// @param partnerProgram partner Program
    /// @param nameIndex name Index
    function initialize(
        address adminDAO,
        address admin,
        address acceptToken,
        address adapter,
        uint256 startPrice,
        uint256 rebalancePeriod,
        address[] memory newAssets,
        address tresuare,
        address partnerProgram,
        address communityDAO,
        string memory nameIndex
    ) external;

    /// @notice Set Rebalance period
    function setRebalancePeriod(uint256 period) external;

    /// @notice Increase the maximum number of assets in the index
    function incrementMaxAssets() external;

    /// @notice Reduces the maximum number of assets in the index
    function decrementMaxAssets() external;

    /// @notice Removes an asset from the list, after rebalancing, this asset will not be
    function excludeAsset(address asset) external;

    /// @notice Adds an asset to the list, after rebalancing this asset will be added to the index
    function includeAsset(address asset) external;

    /// @notice Returns the maximum fraction
    function getMaxAssets() external view returns (uint256);
}
