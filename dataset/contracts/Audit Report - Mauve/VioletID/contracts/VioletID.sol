// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    AccessTokenConsumerUpgradeable
} from "@violetprotocol/ethereum-access-token/contracts/upgradeable/AccessTokenConsumerUpgradeable.sol";

import { IVioletID } from "./IVioletID.sol";
import { StatusMap } from "./StatusMap.sol";

error BatchSetStatusArrayMismatch();

/**
 * @dev VioletID contract
 *
 * Implements IVioletID with additional features:
 *      - AccessControl
 *      - Pausable
 *      - Upgradeable
 *      - Ethereum Access Token compatible
 */
// solhint-disable-next-line contract-name-camelcase
contract VioletIDv1_4_0 is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IVioletID,
    StatusMap,
    AccessTokenConsumerUpgradeable
{
    /**
     * @dev Owner role for:
     *      - Upgrading
     *      - Pausing
     *      - Role Managing
     */
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /**
     * @dev Admin role for:
     *      - Granting statuses
     *      - Revoking statuses
     */
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev See {Initializable}
     *
     * Initializes other parent contract setups
     *
     * Creates the OWNER_ROLE and ADMIN_ROLE and assigns to msg.sender
     */
    function initialize(address _eatVerifier) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __AccessTokenConsumer_init(_eatVerifier);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE); // OWNER_ROLE can change OWNER_ROLE
        _setRoleAdmin(ADMIN_ROLE, OWNER_ROLE); // OWNER_ROLE can change ADMIN_ROLE
        _grantRole(OWNER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev See {PausableUpgradeable-_pause}
     *
     * Only callable by OWNER_ROLE
     *
     * Disables status granting and revoking functions
     */
    function pause() public onlyRole(OWNER_ROLE) {
        _pause();
    }

    /**
     * @dev See {PausableUpgradeable-_unpause}
     *
     * Only callable by OWNER_ROLE
     *
     * Enables status granting and revoking functions
     */
    function unpause() public onlyRole(OWNER_ROLE) {
        _unpause();
    }

    /**
     * @dev See {IVioletID-hasStatus}
     */
    function hasStatus(address account, uint8 statusId) public view override returns (bool) {
        return _isStatusSet(account, statusId);
    }

    /**
     * @dev See {IVioletID-hasStatuses}
     */
    function hasStatuses(address account, uint256 statusCombinationId) public view override returns (bool) {
        return _areStatusesSet(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-claimStatuses}
     *
     * Only callable if contract is not paused
     */
    function claimStatuses(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint256 expiry,
        address account,
        uint256 statusCombinationId
    ) public requiresAuth(v, r, s, expiry) whenNotPaused {
        _assignMultipleStatuses(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-grantStatus}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function grantStatus(address account, uint8 statusId) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        _assignStatus(account, statusId);
    }

    /**
     * @dev See {IVioletID-grantStatuses}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function grantStatuses(
        address account,
        uint256 statusCombinationId
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        _assignMultipleStatuses(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-setStatuses}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function setStatuses(
        address account,
        uint256 statusCombinationId
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        _overwriteMultipleStatuses(account, statusCombinationId);
    }

    /**
     * @dev See {IVioletID-batchSetStatuses}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function batchSetStatuses(
        address[] calldata accountArray,
        uint256[] calldata statusCombinationIdArray
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        uint256 length = accountArray.length;
        if (length != statusCombinationIdArray.length) revert BatchSetStatusArrayMismatch();
        for (uint256 i = 0; i < length; ) {
            _overwriteMultipleStatuses(accountArray[i], statusCombinationIdArray[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IVioletID-revokeStatus}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function revokeStatus(address account, uint8 statusId) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        _unassignStatus(account, statusId);
    }

    /**
     * @dev See {IVioletID-revokeStatuses}
     *
     * Only callable if contract is not paused
     * Only callable by ADMIN_ROLE
     */
    function revokeStatuses(
        address account,
        uint256 statusCombinationId
    ) public override onlyRole(ADMIN_ROLE) whenNotPaused {
        _unassignMultipleStatuses(account, statusCombinationId);
    }

    function updateVerifier(address newVerifier) external onlyRole(OWNER_ROLE) {
        setVerifier(newVerifier);
    }

    /**
     * @dev See {UUPSUpgradeable-_authorizeUpgrade}
     *
     * Only callable by OWNER_ROLE
     *
     * Overrides the hook which runs when upgrading to restrict calls to only OWNER_ROLE
     */
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(OWNER_ROLE) {}

    /**
     * @dev EIP-165 compatibility as required by AccessControlUpgradeable
     *
     * See {AccessControlUpgradeable-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view override(AccessControlUpgradeable) returns (bool) {
        return interfaceId == type(IVioletID).interfaceId || super.supportsInterface(interfaceId);
    }
}
