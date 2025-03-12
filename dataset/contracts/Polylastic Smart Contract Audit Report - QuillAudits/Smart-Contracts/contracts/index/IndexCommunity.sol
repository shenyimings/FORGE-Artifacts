// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../index/Index.sol";
import "../index/IIndexCommunity.sol";

contract IndexCommunity is Index, IIndexCommunity {
    bytes32 public constant DAO_COMMUNITY_ROLE =
        keccak256("DAO_COMMUNITY_ROLE");

    /// @notice triggered when an asset is removed from the list
    event ExcludeAsset(address asset);
    /// @notice triggered when an asset is added to the list
    event IncludeAsset(address asset);
    /// @notice triggered when the "maxAssets" parameter is changed
    event MaxAssets(uint256 maxAssets);

    uint256 private _maxAssets;

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
    ) external {
        _setupRole(DAO_COMMUNITY_ROLE, communityDAO);
        _initialize(
            adminDAO,
            admin,
            acceptToken,
            adapter,
            startPrice,
            rebalancePeriod,
            newAssets,
            tresuare,
            partnerProgram,
            nameIndex
        );
        _maxAssets = 10;
    }

    /// @notice Set Rebalance period
    /// @dev Can only be called by a user with the right DAO_COMMUNITY_ROLE
    function setRebalancePeriod(uint256 period)
        external
        onlyRole(DAO_COMMUNITY_ROLE)
    {
        require(period >= 30 days && period <= 365 days, "Invalid period");
        _setRebalancePeriod(period);
    }

    /// @notice Increase the maximum number of assets in the index
    /// @dev Can only be called by a user with the right DAO_COMMUNITY_ROLE

    function incrementMaxAssets() external onlyRole(DAO_COMMUNITY_ROLE) {
        _maxAssets++;
        require(
            _maxAssets <= 10,
            "Overall number of assets couldn't be more than 10."
        );
        emit MaxAssets(_maxAssets);
    }

    /// @notice Reduces the maximum number of assets in the index
    /// @dev Can only be called by a user with the right DAO_COMMUNITY_ROLE
    function decrementMaxAssets() external onlyRole(DAO_COMMUNITY_ROLE) {
        require(
            _maxAssets >= 5,
            "Overall number of assets couldn't be less than 5."
        );
        _maxAssets--;
        emit MaxAssets(_maxAssets);
    }

    /// @notice Removes an asset from the list, after rebalancing, this asset will not be
    /// @dev Can only be called by a user with the right DAO_COMMUNITY_ROLE
    function excludeAsset(address asset) external onlyRole(DAO_COMMUNITY_ROLE) {
        _removeInNewAssets(asset);

        emit ExcludeAsset(asset);
    }

    /// @notice Adds an asset to the list, after rebalancing this asset will be added to the index
    /// @dev Can only be called by a user with the right DAO_COMMUNITY_ROLE
    function includeAsset(address asset) external onlyRole(DAO_COMMUNITY_ROLE) {
        require(lengthNewAssets() < _maxAssets, "Max assets");
        _addAssetInNewAssets(asset);

        emit IncludeAsset(asset);
    }

    /// @notice Returns the maximum fraction
    function getMaxAssets() external view returns (uint256) {
        return (_maxAssets);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IIndexCommunity).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
