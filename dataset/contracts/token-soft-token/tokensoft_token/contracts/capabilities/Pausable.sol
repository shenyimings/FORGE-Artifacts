pragma solidity 0.6.12;

import "../roles/PauserRole.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
contract Pausable is PauserRole {
    /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by an Owner to pause, triggers stopped state.
     */
    function _pause() internal {
        _paused = true;
        emit Paused(msg.sender);
    }

    /**
     * @dev Called by an Owner to unpause, returns to normal state.
     */
    function _unpause() internal {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @dev Called by an Owner to pause, triggers stopped state.
     */
    function pause() public onlyPauser whenNotPaused {
        Pausable._pause();
    }

    /**
     * @dev Called by an Owner to unpause, returns to normal state.
     */
    function unpause() public onlyPauser whenPaused {
        Pausable._unpause();
    }
}