// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Aspida's manager module
 * @author Aspida engineer
 */
abstract contract Manable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev EnumerableSet of managers
    EnumerableSet.AddressSet internal managers_;

    /**
     * @dev Emitted when `manager` is added as `managers`.
     */
    event ManagerAdded(address manager);

    /**
     * @dev Emitted when `manager` is removed from `managers`.
     */
    event ManagerRemoved(address manager);

    /**
     * @dev Throws if called by any account other than the managers.
     */
    modifier onlyManager() {
        require(managers_.contains(msg.sender), "onlyManager: caller is not manager");
        _;
    }

    /**
     * @notice Add `manager` into managers.
     * If `manager` have not been a manager, emits a `ManagerAdded` event.
     *
     * @param _manager The manager to add
     */
    function _addManagerInternal(address _manager) internal virtual {
        require(_manager != address(0), "_addManagerInternal: _manager the zero address");
        require(managers_.add(_manager), "_addManagerInternal: _manager has been added");
        emit ManagerAdded(_manager);
    }

    /**
     * @notice Remove `manager` from managers.
     * If `manager` is a manager, emits a `ManagerRemoved` event.
     *
     * @param _manager The manager to remove
     */
    function _removeManagerInternal(address _manager) internal virtual {
        require(managers_.remove(_manager), "_removeManagerInternal: _manager has been removed");
        emit ManagerRemoved(_manager);
    }

    /**
     * @notice Return all managers
     * @return _managers The list of manager addresses
     */
    function managers() public view returns (address[] memory _managers) {
        _managers = managers_.values();
    }

    /**
     * @dev Check if address is manager
     * @param _manager The address to check
     * @return Is manager boolean, true: is the manager; false: not the manager
     */
    function isManager(address _manager) public view returns (bool) {
        return managers_.contains(_manager);
    }
}
