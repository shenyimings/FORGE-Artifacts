//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

interface IFactory {
    event ChangeIndexMaster(address oldIndexMaster, address newIndexMaster);
    event Mint(address instance);
    event ChangeMainParam(
        address DAOAddress,
        address validator,
        address USD,
        address adapter,
        address tresuare,
        uint256 rebalancePeriod
    );
    event ChangeMainParamCommunity(
        address DAOAdminAddress,
        address DAOCommunityAddress,
        address validator,
        address USD,
        address adapter,
        address tresuare,
        uint256 rebalancePeriod
    );

    /// @notice Creating an index
    /// @param startPrice Start price
    /// @param newAssets Assets in the index
    /// @param nameIndex Index name
    function mint(
        uint256 startPrice,
        address[] memory newAssets,
        string memory nameIndex
    ) external;

    /// @notice Change the implementation address
    function changeIndexMaster(address newIndexMaster) external;

    /// @notice Return a list of indexes created through the factory
    function getIndexes() external view returns (address[] memory);

    /// @notice Return the main parameters
    function getMainParam()
        external
        view
        returns (
            address indexMaster,
            address DAOAddress,
            address validator,
            address USD,
            address adapter,
            address tresuare,
            uint256 rebalancePeriod,
            address ipartnerProgram
        );
}
