// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {SolidStateDiamond} from "@solidstate/contracts/proxy/diamond/SolidStateDiamond.sol";
import {Proxy} from "@solidstate/contracts/proxy/Proxy.sol";
import {IProxy} from "@solidstate/contracts/proxy/IProxy.sol";

import {AddressUtils} from "@solidstate/contracts/utils/AddressUtils.sol";
import {LibIssuer} from "./libraries/LibIssuer.sol";
import {LibClaimManager} from "./libraries/LibClaimManager.sol";

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";

/**
 * @title Greenproof - a certification system for issuing, revoking and managing green certificates
 * @author Energyweb Foundation
 * @dev This contract is the main proxy contract of the upgradable Greenproof core module.
 */

contract Greenproof is SolidStateDiamond {
    using AddressUtils for address;

    bool private _isContractPaused;

    /**
     * @notice IssuerVersionUpdated - logs issuer role version updates
     * @param oldVersion - The value of the previous issuer role credential
     * @param newVersion - The value of the updated issuer role credential
     * @dev Event emitted when the version of the issuer role is updated
     */
    event IssuerVersionUpdated(uint256 indexed oldVersion, uint256 indexed newVersion);

    /**
     * @notice WorkerVersionUpdated - logs worker role version updates
     * @param oldVersion - The value of the previous worker role credential
     * @param newVersion - The value of the updated worker role credential
     * @dev Event emitted when the version of the worker role is updated
     */
    event WorkerVersionUpdated(uint256 indexed oldVersion, uint256 indexed newVersion);

    /**
     * @notice RevokerVersionUpdated - logs Revoker role version updates
     * @param oldVersion - The value of the previous revoker role credential
     * @param newVersion - The value of the updated revoker role credential
     * @dev Event emitted when the version of the revoker role is updated
     */
    event RevokerVersionUpdated(uint256 indexed oldVersion, uint256 indexed newVersion);

    /**
     * @notice ClaimerVersionUpdated - logs claimer role version updates
     * @param oldVersion - The value of the previous claimer role credential
     * @param newVersion - The value of the updated claimer role credential
     * @dev Event emitted when the version of the claimer role is updated
     */
    event ClaimerVersionUpdated(uint256 indexed oldVersion, uint256 indexed newVersion);

    /**
     * @notice ApproverVersionUpdated - logs Approver role version updates
     * @param oldVersion - The value of the previous approver role credential
     * @param newVersion - The value of the updated approver role credential
     * @dev Event emitted when the version of the approver role is updated
     */
    event ApproverVersionUpdated(uint256 indexed oldVersion, uint256 indexed newVersion);

    /**
     * @notice ClaimManagerUpdated - logs claim manager contract's address updates
     * @param oldAddress - The previous value of the claim manager contract address
     * @param newAddress - The updated value of the claim manager contract address
     * @dev Event emitted when the address of the claim manager contract is updated
     */
    event ClaimManagerUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice ClaimsRevocationRegistryUpdated - logs claim revocation registry's address updates
     * @param oldAddress - The previous value of the claim revocation registry address
     * @param newAddress - The updated value of claim revocation registry address
     * @dev Event emitted when the claim revocation registry address is updated
     */
    event ClaimsRevocationRegistryUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice ContractPaused - emitted when the contract gets paused
     * @param timestamp unix date and time recording when the contract was paused
     * @param operator - address of the operator who paused the contract
     */
    event ContractPaused(uint256 timestamp, address operator);

    /**
     * @notice ContractUnPaused - emitted when the contract gets paused
     * @param timestamp unix date and time recording when the contract was unpaused
     * @param operator - address of the operator who unpaused the contract
     */
    event ContractUnPaused(uint256 timestamp, address operator);

    /**
     * @dev Error: Thrown when a transaction occurs while contract is paused
     */
    error PausedContract();

    /**
     * @dev Error: Thrown when contract owner is trying to pause an already paused contract
     */
    error AlreadyPausedContract();

    /**
     * @dev Error: Thrown when contract owner is trying to unpause an already unpaused contract
     */
    error AlreadyUnpausedContract();

    /**
     * @notice constructor
     * @param contractOwner - address of the contract owner
     */
    constructor(address contractOwner) payable {
        if (contractOwner == address(0)) {
            revert LibDiamond.ProxyError("init: Invalid contract Owner");
        }
        OwnableStorage.layout().owner = contractOwner;
    }

    fallback() external payable override(IProxy, Proxy) {
        if (_isContractPaused) {
            revert PausedContract();
        }
        address implementation = _getImplementation();

        LibDiamond.redirectToFacet(implementation);
    }

    /**
     * @notice updateClaimManager
     * @param newAddress The new address of the claim manager
     * @dev Allows only the contract owner to update the claim manager address.
     * @dev This restriction is set on the internal `setClaimManagerAddress` function
     */
    function updateClaimManager(address newAddress) external {
        /**
         * @dev `setClaimManagerAddress` updates the claim manager address and retrieves the old address for logging purposes
         */
        address oldAddress = LibClaimManager.setClaimManagerAddress(newAddress);

        /**
         * @dev Emitting event for the updated claim manager address
         */
        emit ClaimManagerUpdated(oldAddress, newAddress);
    }

    /**
     * @notice updateClaimRevocationRegistry
     * @param newAddress The new address of the claim revocation registry
     * @dev Allows only the contract owner to update the claim revocation registry address
     * @dev This restriction is set on the internal `setClaimRevocationRegistry` function
     */
    function updateClaimRevocationRegistry(address newAddress) external {
        /**
         * @dev `setClaimRevocationRegistry` updates the claim revocation registry address and retrieves the old address for logging purposes
         */
        address oldAddress = LibClaimManager.setClaimRevocationRegistry(newAddress);

        /**
         * @dev Emitting event for the updated claim revocation registry address
         */
        emit ClaimsRevocationRegistryUpdated(oldAddress, newAddress);
    }

    /**
     * @notice updateIssuerVersion
     * @param newVersion The new version of the issuer role
     * @dev Allows only the contract owner to update the issuer version
     * @dev This restriction is set on the internal `setIssuerVersion` function
     */
    function updateIssuerVersion(uint256 newVersion) external {
        /**
         * @dev `setIssuerVersion` updates the issuer role version and retrieves the previous version for logging purposes
         */
        uint256 oldVersion = LibClaimManager.setIssuerVersion(newVersion);

        /**
         * @dev Emitting event for the updated issuer role version
         */
        emit IssuerVersionUpdated(oldVersion, newVersion);
    }

    /**
     * @notice updateRevokerVersion
     * @param newVersion The new version of the revoker role
     * @dev Allows only the contract owner to update the revoker version
     * @dev This restriction is set on the internal `setRevokerVersion` function
     */
    function updateRevokerVersion(uint256 newVersion) external {
        /**
         * @dev `setRevokerVersion` updates the revoker role version and retrieves the previous version for logging purposes
         */
        uint256 oldVersion = LibClaimManager.setRevokerVersion(newVersion);

        /**
         * @dev Emitting event for the updated revoker role version
         */
        emit RevokerVersionUpdated(oldVersion, newVersion);
    }

    /**
     * @notice updateWorkerVersion
     * @param newVersion The new version of the worker role
     * @dev Allows only the contract owner to update the worker version
     * @dev This restriction is set on the internal `setWorkerVersion` function
     */
    function updateWorkerVersion(uint256 newVersion) external {
        /**
         * @dev `setWorkerVersion` updates the worker role version and retrieves the previous version for logging purposes
         */
        uint256 oldVersion = LibClaimManager.setWorkerVersion(newVersion);

        /**
         * @dev Emitting event for the updated worker role version
         */
        emit WorkerVersionUpdated(oldVersion, newVersion);
    }

    /**
     * @notice updateClaimerVersion
     * @param newVersion The new version of the claimer role
     * @dev Allows only the contract owner to update the claimer version
     * @dev This restriction is set on the internal `setClaimerVersion` function
     */
    function updateClaimerVersion(uint256 newVersion) external {
        /**
         * @dev `setClaimerVersion` updates the claimer role version and retrieves the previous version for logging purposes
         */
        uint256 oldVersion = LibClaimManager.setClaimerVersion(newVersion);

        /**
         * @dev Emitting event for the updated claimer role version
         */
        emit ClaimerVersionUpdated(oldVersion, newVersion);
    }

    /**
     * @notice updateApproverVersion
     * @param newVersion The new version of the claimer role
     * @dev Allows only the contract owner to update the claimer version
     * @dev This restriction is set on the internal `setApproverVersion` function
     */
    function updateApproverVersion(uint256 newVersion) external {
        /**
         * @dev `setApproverVersion` updates the claimer role version and retrieves the previous version for logging purposes
         */
        uint256 oldVersion = LibClaimManager.setApproverVersion(newVersion);

        /**
         * @dev Emitting event for the updated claimer role version
         */
        emit ApproverVersionUpdated(oldVersion, newVersion);
    }

    /**
     * @notice pause - when called, this function prevents all calls of facet functions from being executed
     * @dev only the contract admistrator is allowed to execute this halting function
     * @dev if the system is already paused, a call to this function will revert with `AlreadyPausedContract` error
     */
    function pause() external {
        LibClaimManager.checkOwnership();

        if (_isContractPaused) {
            revert AlreadyPausedContract();
        }
        _isContractPaused = true;

        // solhint-disable-next-line not-rely-on-time
        emit ContractPaused(block.timestamp, msg.sender);
    }

    /**
     * @notice unPause - when called, this function reverts the pausing and unlocks facet function executions
     * @dev only the contract admistrator is allowed to execute this unlocking function
     * @dev if the system is already unpaused, a call to this function will revert with `AlreadyUnpausedContract` error
     */
    function unPause() external {
        LibClaimManager.checkOwnership();

        if (!_isContractPaused) {
            revert AlreadyUnpausedContract();
        }
        _isContractPaused = false;

        // solhint-disable-next-line not-rely-on-time
        emit ContractUnPaused(block.timestamp, msg.sender);
    }
}
