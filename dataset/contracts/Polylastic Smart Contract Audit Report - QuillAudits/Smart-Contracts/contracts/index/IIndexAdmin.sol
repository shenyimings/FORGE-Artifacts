//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

interface IIndexAdmin {
    /// @notice Initialization of the main parameters
    /// @param adminDAO The address that has the right to call functions with the "DAO_ADMIN_ROLE" role
    /// @param admin The address that has the right to call functions with the "ADMIN_ROLE" role
    /// @param acceptToken The token in which the payment is accepted
    /// @param adapter Adapter DEX
    /// @param startPrice Initial index price
    /// @param rebalancePeriod The time after which rebalancing occurs (seconds)
    /// @param newAssets Array with asset addresses
    /// @param tresuare A commission will be sent to this address
    /// @param partnerProgram Partner Program
    /// @param nameIndex Name Index
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
        string memory nameIndex
    ) external;

    /// @notice Set the maximum index share
    function setMaxShare(uint256 maxShare) external;

    /// @notice Set Rebalance period
    function setRebalancePeriod(uint256 period) external;

    /// @notice Sets a new list of assets after rebalancing
    function newIndexComposition(address[] calldata assets) external;
}
