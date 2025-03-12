// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "../index/Index.sol";
import "../index/IIndexAdmin.sol";

contract IndexAdmin is Index, IIndexAdmin {
    /// @notice triggered when changing the list of new assets
    event NewIndexComposition(address[] asset);
    /// @notice triggered when the maximum fraction is changed
    event SetMaxShare(uint256 maxShare);

    receive() external payable{}

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
    ) external {
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
    }

    /// @notice Set the maximum index share
    /// @dev Can only be called by a user with the right DAO_ADMIN_ROLE
    function setMaxShare(uint256 maxShare) external onlyRole(DAO_ADMIN_ROLE) {
        require(
            maxShare >= 20 * PRECISION_E6 && maxShare <= 100 * PRECISION_E6,
            "Invalid Share"
        );
        _setMaxShare(maxShare);
        emit SetMaxShare(maxShare);
    }

    /// @notice Set Rebalance period
    /// @dev Can only be called by a user with the right DAO_ADMIN_ROLE
    function setRebalancePeriod(
        uint256 period
    ) external onlyRole(DAO_ADMIN_ROLE) {
        require(period > 6 hours, "min period 6 hours");
        _setRebalancePeriod(period);
    }

    /// @notice Sets a new list of assets after rebalancing
    /// @dev Can only be called by a user with the right DAO_ADMIN_ROLE
    function newIndexComposition(
        address[] calldata assets
    ) external onlyRole(DAO_ADMIN_ROLE) {
        _clearNewAssets();
        _updateNewAssets(assets);
        emit NewIndexComposition(assets);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IIndexAdmin).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
