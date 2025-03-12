// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "./RolesHandler.sol";

/**
 * @title Freezeable
 * @dev An abstract contract for managing the freeze status of a contract.
 */
abstract contract Freezeable is RolesHandler {
    /// @notice holds current freeze status
    bool public freezeStatus = true;

    /// @notice contract has freezed
    event Freeze(bool indexed status);

    /**
     * @dev Modifier to check if the contract is not freezed.
     */
    modifier isFreezed() {
        require(freezeStatus == true, "Freezeable: Contract is not freezed");
        _;
    }

    /**
     * @dev Modifier to check if the contract is freezed.
     */
    modifier isNotFreezed() {
        require(freezeStatus == false, "Freezeable: Contract is freezed");
        _;
    }

    /**
     * @dev Sets the freeze status of the contract.
     * @param status The new freeze status (true for freezed, false for not freezed).
     */
    function setFreeze(bool status) external onlyOwnerRole(msg.sender) {
        freezeStatus = status;
        emit Freeze(status);
    }
}
