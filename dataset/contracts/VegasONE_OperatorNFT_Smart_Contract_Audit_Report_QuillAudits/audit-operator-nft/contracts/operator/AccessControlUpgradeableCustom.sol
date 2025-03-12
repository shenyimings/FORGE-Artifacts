// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract AccessControlUpgradeableCustom is
    Initializable,
    AccessControlUpgradeable
{
    using AddressUpgradeable for address;

    /**
     * Global Variables
     */
    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");
    mapping(address => address) private _inTransition;

    /**
     * Events
     */

    event TransferAdmin(address adminAddress);
    event UpdateAdmin(address oldAdminAddress);
    event CancelTransferAdmin(address newAdminAddress);

    /**
     * Errors
     */

    error ErrIntransition();
    error ErrNotIntransition();
    error ErrInvalidTransition();
    error ErrGrantRoleInValidAddress();
    error ErrGrantZeroAddress();

    /**
     * modifier
     */

    /**
     * @dev Modifier to make a function callable only when the transition exist.
     *
     * Requirements:
     *
     * - The transition must exist.
     */
    modifier inTransition(address oldAdmin) {
        if (_inTransition[oldAdmin] == address(0)) {
            revert ErrNotIntransition();
        }
        _;
    }

    /**
     * @dev Modifier to make a function callable only when there's no transition pending.
     *
     * Requirements:
     *
     * - No transition is pending.
     */
    modifier notInTransition() {
        if (_inTransition[_msgSender()] != address(0)) {
            revert ErrIntransition();
        }
        _;
    }

    /**
     * Functions
     */

    function __AccessControlCustom_init(
        address newAdmin,
        address[] memory newWorkers
    ) internal onlyInitializing {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _batchGrantWorker(newWorkers);
    }

    /**
     * @dev return whom the Admin role is transfered to
     * @param admin address - the original Admin
     */
    function transition(address admin) external view returns (address) {
        return _inTransition[admin];
    }

    /**
     * @dev grant admin to newAdmin, and set a pending transition in record
     * @param newAdmin address - the address that Admin role is transfered to
     * @notice - Only admin can call this function.
     */
    function transferAdmin(
        address newAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) notInTransition {
        if (newAdmin == address(0) || hasRole(DEFAULT_ADMIN_ROLE, newAdmin)) {
            revert ErrGrantRoleInValidAddress();
        }
        _inTransition[_msgSender()] = newAdmin;
        emit TransferAdmin(newAdmin);
    }

    /**
     * @dev the address who gets admin from transition are able to accept and revoke the old Admin
     * @param oldAdmin address - the original Admin address
     */
    function updateAdmin(address oldAdmin) external inTransition(oldAdmin) {
        if (_inTransition[oldAdmin] != _msgSender()) {
            revert ErrInvalidTransition();
        }
        _inTransition[oldAdmin] = address(0);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _revokeRole(DEFAULT_ADMIN_ROLE, oldAdmin);
        emit UpdateAdmin(oldAdmin);
    }

    /**
     * @dev former Admin can cancel its transition
     * @notice - Only admin can call this function.
     */
    function cancelTransferAdmin()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        inTransition(_msgSender())
    {
        address adminToBeCanceled = _inTransition[_msgSender()];
        _inTransition[_msgSender()] = address(0);
        _revokeRole(DEFAULT_ADMIN_ROLE, adminToBeCanceled);
        emit CancelTransferAdmin(adminToBeCanceled);
    }

    /**
     * @dev grant Worker to addresses
     * @param newWorkers address[] - list of addresses going to get Worker role
     * @notice - Only admin can call this function.
     */
    function batchGrantWorker(
        address[] memory newWorkers
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _batchGrantWorker(newWorkers);
    }

    /**
     * @dev grant Worker to addresses
     */
    function _batchGrantWorker(address[] memory newWorkers) internal {
        for (uint256 i = 0; i < newWorkers.length; i++) {
            if (newWorkers[i] == address(0)) {
                revert ErrGrantZeroAddress();
            }
            _grantRole(WORKER_ROLE, newWorkers[i]);
        }
    }
}
