// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Aspida's PauseGuardian module
 * @author Aspida engineer
 */
abstract contract PauseGuardian is PausableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev EnumerableSet of pauseGuardians
    EnumerableSet.AddressSet internal pauseGuardians_;

    /**
     * @dev Emitted when `pauseGuardian` is added as `pauseGuardian`.
     */
    event PauseGuardianAdded(address pauseGuardian);

    /**
     * @dev Emitted when `pauseGuardian` is removed from `pauseGuardians`.
     */
    event PauseGuardianRemoved(address pauseGuardian);

    /**
     * @dev Throws if called by any account other than pauseGuardian.
     */
    modifier onlyPauseGuardian() {
        require(isPauseGuardian(msg.sender), "onlyPauseGuardian: caller is not pauseGuardian");
        _;
    }

    /**
     * @notice Add `pauseGuardian` into pauseGuardians.
     * If `pauseGuardian` have not been a pauseGuardian, emits a `PauseGuardianAdded` event.
     *
     * @param _pauseGuardian The pauseGuardian to add
     */
    function _addPauseGuardianInternal(address _pauseGuardian) internal virtual {
        require(_pauseGuardian != address(0), "_addPauseGuardianInternal: _pauseGuardian the zero address");
        require(pauseGuardians_.add(_pauseGuardian), "_addPauseGuardianInternal: _pauseGuardian has been added");
        emit PauseGuardianAdded(_pauseGuardian);
    }

    /**
     * @notice Remove `pauseGuardian` from pauseGuardians.
     * If `pauseGuardian` is a pauseGuardian, emits a `PauseGuardianRemoved` event.
     *
     * @param _pauseGuardian The pauseGuardian to remove
     */
    function _removePauseGuardianInternal(address _pauseGuardian) internal virtual {
        require(
            pauseGuardians_.remove(_pauseGuardian),
            "_removePauseGuardianInternal: _pauseGuardian has been removed"
        );
        emit PauseGuardianRemoved(_pauseGuardian);
    }

    /**
     * @notice Return all pauseGuardians
     * @return _pauseGuardians The list of pauseGuardian addresses
     */
    function pauseGuardians() public view returns (address[] memory _pauseGuardians) {
        _pauseGuardians = pauseGuardians_.values();
    }

    /**
     * @dev Check if address is pauseGuardian
     * @param _pauseGuardian The address to check
     * @return Is pauseGuardian boolean, true: is the pauseGuardian; false: not the pauseGuardian
     */
    function isPauseGuardian(address _pauseGuardian) public view virtual returns (bool) {
        return pauseGuardians_.contains(_pauseGuardian);
    }
}
