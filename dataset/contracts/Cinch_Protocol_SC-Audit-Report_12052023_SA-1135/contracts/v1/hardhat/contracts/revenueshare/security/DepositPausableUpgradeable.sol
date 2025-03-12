// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract DepositPausableUpgradeable is Initializable, ContextUpgradeable, OwnableUpgradeable {
    bool private _depositPaused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event DepositPaused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event DepositUnpaused(address account);

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenDepositNotPaused() {
        _requireDepositNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenDepositPaused() {
        _requireDepositPaused();
        _;
    }

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __DepositPausable_init() internal onlyInitializing {
        __DepositPausable_init_unchained();
    }

    function __DepositPausable_init_unchained() internal onlyInitializing {
        _depositPaused = false;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pauseDeposit() external virtual whenDepositNotPaused onlyOwner {
        _depositPaused = true;
        emit DepositPaused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpauseDeposit() external virtual whenDepositPaused onlyOwner {
        _depositPaused = false;
        emit DepositUnpaused(_msgSender());
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function depositPaused() public view virtual returns (bool) {
        return _depositPaused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireDepositNotPaused() internal view virtual {
        require(!depositPaused(), "DepositPausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requireDepositPaused() internal view virtual {
        require(depositPaused(), "DepositPausable: unpaused");
    }
}
