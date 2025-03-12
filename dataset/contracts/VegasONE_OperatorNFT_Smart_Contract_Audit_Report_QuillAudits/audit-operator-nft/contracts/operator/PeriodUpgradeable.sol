// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract PeriodUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the startPeriod is triggered by `account`.
     */
    event Period(address account, uint256 currentPeriod);

    /**
     * @dev Emitted when the DuringPeriod is lifted by `account`.
     */
    event UnPeriod(address account);

    /**
     * Errors
     */
    error ErrNotInPeriod();
    error ErrAlreadyInPeriod();

    bool private _duringPeriod;
    uint256 private _currentPeriod;

    /**
     * @dev Initializes the contract in _endPeriod state.
     */
    function __DuringPeriod_init() internal onlyInitializing {
        __DuringPeriod_init_unchained();
    }

    function __DuringPeriod_init_unchained() internal onlyInitializing {
        _duringPeriod = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function duringPeriod() public view virtual returns (bool) {
        return _duringPeriod;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is during period.
     *
     * Requirements:
     *
     * - The contract must be during period.
     */
    modifier whenInPeriod() {
        if (!duringPeriod()) {
            revert ErrNotInPeriod();
        }
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not during period.
     *
     * Requirements:
     *
     * - The contract must be not during period.
     */
    modifier whenNotInPeriod() {
        if (duringPeriod()) {
            revert ErrAlreadyInPeriod();
        }
        _;
    }

    /**
     * @dev return current period
     */
    function currentPeriod() public view returns (uint256) {
        return _currentPeriod;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not during period.
     */
    function _startPeriod() internal virtual whenNotInPeriod {
        _duringPeriod = true;
        _currentPeriod += 1;
        emit Period(_msgSender(), _currentPeriod);
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be during period.
     */
    function _endPeriod() internal virtual whenInPeriod {
        _duringPeriod = false;
        emit UnPeriod(_msgSender());
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}
