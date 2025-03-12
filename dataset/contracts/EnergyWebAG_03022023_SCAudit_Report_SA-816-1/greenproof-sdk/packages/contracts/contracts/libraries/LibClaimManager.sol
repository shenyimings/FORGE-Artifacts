//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import {IClaimManager} from "../interfaces/IClaimManager.sol";

/**
 * @title LibClaimManager
 * @dev Library for managing claims and roles for the Greenproof smart contract.
 * @author EnergyWeb Foundation
 */
library LibClaimManager {
    /**
     * @notice Struct for storing role information.
     * @param name - the role name
     * @param version - the role version
     */
    struct Role {
        bytes32 name;
        uint256 version;
    }

    /**
     * @dev Structure storing the configuration of greenproof's roles credentials
     * @custom:field issuerRole - Credential role name granting issuance rights
     * @custom:field revokerRole - Credential role name granting revoker rights
     * @custom:field workerRole - Credential role name allowing voters to be whitelisted and authorized in the voting system
     * @custom:field claimerRole - Credential role name allowing to claim a certificate on the behalf of others
     * @custom:field approverRole - Credential role name allowing to set certificate transfer approvals on the behalf of others
     * @custom:field claimManagerAddress - Address of the Energy web's claim manager registy, handling DID-based roles
     * @custom:field claimsRevocationRegistry -  Address of the Energy web's claimsRevocationRegistry, handling credential revocations
     */
    struct RolesConfig {
        bytes32 issuerRole;
        bytes32 revokerRole;
        bytes32 workerRole;
        bytes32 claimerRole;
        bytes32 approverRole;
        address claimManagerAddress;
        address claimsRevocationRegistry;
    }

    /**
     * @notice Struct for storing claim manager storage information.
     * @custom:field claimManagerAddress -  Address of the claim manager contract.
     * @custom:field claimsRevocationRegistry - Address of the claims revocation registry contract.
     * @custom:field workerRole - Role for the worker.
     * @custom:field issuerRole - Role for the issuer.
     * @custom:field revokerRole - Role for the revoker.
     * @custom:field claimerRole - Role for the revoker
     * @custom:field approverRole - Role for the approver
     */
    struct ClaimManagerStorage {
        address claimManagerAddress;
        address claimsRevocationRegistry;
        Role workerRole;
        Role issuerRole;
        Role revokerRole;
        Role claimerRole;
        Role approverRole;
    }

    /**
     * @dev Constant tracking the storage slot position of the claimerStorage.
     */
    bytes32 private constant _CLAIM_MANAGER_STORAGE_POSITION = keccak256("ewc.greenproof.claimManager.diamond.storage");

    /**
     * @dev Error message for when the claim manager is used not initialized.
     */
    error NotInitializedClaimManager();

    /**
     * @dev Error message for when an operator is not enrolled as an issuer.
     * @dev the address of the not enrolled user should be specified in the `operator` param
     */
    error NotEnrolledIssuer(address operator);

    /**
     * @dev Error message for when an operator is not enrolled as a claimer.
     * @dev the address of the not enrolled user should be specified in the `operator` param
     */
    error NotEnrolledClaimer(address operator);

    /**
     * @dev Error message for when an operator is not enrolled as a revoker.
     * @dev the address of the not enrolled user should be specified in the `operator` param
     */
    error NotEnrolledRevoker(address operator);

    /**
     * @dev Error message for when an operator is not enrolled as an approver.
     * @dev the address of the not enrolled user should be specified in the `operator` param
     */
    error NotEnrolledApprover(address operator);

    /**
     * @dev Error message for when an operator is not enrolled as a worker.
     */
    error NotEnrolledWorker(address operator);

    /**
     * @dev Error message for when a worker is not revoked.
     * @dev the address of the not revoked worker should be specified in the `operator` param
     */
    error NotRevokedWorker(address operator);

    /**
     * @dev Error message for when there is an error updating a role.
     * @dev the specific error should be specified in the `errorMessage` string
     */
    error UpdateRoleError(string errorMessage);

    /**
     * @dev Error message for when there is an issue updating an address.
     * @dev the specific error should be specified in the `errorMessage` string
     */
    error UpdateAddressError(string errorMessage);

    /**
     * @dev Error message for when an operator is not authorized.
     * @dev the missing authorization should be specified in the `requiredAuth` string
     */
    error NotAuthorized(string requiredAuth, address operator);

    /**
     * @dev Modifier for allowing only the contract owner to call a function.
     */
    modifier onlyOwner() {
        checkOwnership();
        _;
    }

    /**
     * @dev Function for initializing the claim manager.
     * @custom:field claimManagerAddress Address of the claim manager.
     * @custom:field issuerRole Role name for the issuers.
     * @custom:field revokerRole Role name for revokers
     * @custom:field workerRole Role name for the workerq.
     * @custom:field claimerRole Role name for the claimerq.
     * @custom:field approverRole Role name for the approvers.
     * @custom:field claimsRevocationRegistry Address of the claims revocation registry.
     */
    function init(RolesConfig memory rolesConfig) internal {
        ClaimManagerStorage storage claimStore = getStorage();

        claimStore.claimManagerAddress = rolesConfig.claimManagerAddress;
        claimStore.claimsRevocationRegistry = rolesConfig.claimsRevocationRegistry;
        claimStore.issuerRole = Role({name: rolesConfig.issuerRole, version: 1});
        claimStore.revokerRole = Role({name: rolesConfig.revokerRole, version: 1});
        claimStore.workerRole = Role({name: rolesConfig.workerRole, version: 1});
        claimStore.claimerRole = Role({name: rolesConfig.claimerRole, version: 1});
        claimStore.approverRole = Role({name: rolesConfig.approverRole, version: 1});
    }

    /**
     * @notice Function for updating the version of the issuer role.
     * @param newVersion New version of the issuer role.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldRoleVersion The previous version of the issuer role.
     */
    function setIssuerVersion(uint256 newVersion) internal onlyOwner returns (uint256 oldRoleVersion) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.issuerRole.version == newVersion) {
            revert UpdateRoleError("Same version");
        }

        oldRoleVersion = claimStore.issuerRole.version;

        claimStore.issuerRole.version = newVersion;
    }

    /**
     * @notice Function for updating the version of the worker role.
     * @param newVersion New version of the worker role.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldRoleVersion The previous version of the worker role.
     */
    function setWorkerVersion(uint256 newVersion) internal onlyOwner returns (uint256 oldRoleVersion) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.workerRole.version == newVersion) {
            revert UpdateRoleError("Same version");
        }
        oldRoleVersion = claimStore.workerRole.version;

        claimStore.workerRole.version = newVersion;
    }

    /**
     * @notice Function for updating the version of the revoker role.
     * @param newVersion New version of the revoker role.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldRoleVersion The previous version of the revoker role.
     */
    function setRevokerVersion(uint256 newVersion) internal onlyOwner returns (uint256 oldRoleVersion) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.revokerRole.version == newVersion) {
            revert UpdateRoleError("Same version");
        }
        oldRoleVersion = claimStore.revokerRole.version;

        claimStore.revokerRole.version = newVersion;
    }

    /**
     * @notice setApproverVersion - Function for updating the version of the approver role.
     * @param newVersion New version of the approver role.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldRoleVersion The previous version of the approver role.
     */
    function setApproverVersion(uint256 newVersion) internal onlyOwner returns (uint256 oldRoleVersion) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.approverRole.version == newVersion) {
            revert UpdateRoleError("Same version");
        }
        oldRoleVersion = claimStore.approverRole.version;

        claimStore.approverRole.version = newVersion;
    }

    /**
     * @notice Function for updating the version of the claimer role.
     * @param newVersion New version of the claimer role.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldRoleVersion The previous version of the claimer role.
     */
    function setClaimerVersion(uint256 newVersion) internal onlyOwner returns (uint256 oldRoleVersion) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.claimerRole.version == newVersion) {
            revert UpdateRoleError("Same version");
        }

        oldRoleVersion = claimStore.claimerRole.version;

        claimStore.claimerRole.version = newVersion;
    }

    /**
     * @notice Function for updating the address of the claim manager.
     * @param newAddress New address of the claim manager.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldAddress The previous address of the claim manager.
     */
    function setClaimManagerAddress(address newAddress) internal onlyOwner returns (address oldAddress) {
        ClaimManagerStorage storage claimStore = getStorage();

        if (newAddress == address(0)) {
            revert UpdateRoleError("Cannot update to null address");
        }

        if (claimStore.claimManagerAddress == newAddress) {
            revert UpdateRoleError("Same address");
        }

        oldAddress = claimStore.claimManagerAddress;

        claimStore.claimManagerAddress = newAddress;
    }

    /**
     * @notice Function for updating the address of the claims revocation registry.
     * @param newAddress New address of the claims revocation registry.
     * @dev This function can only be called by the owner of the Greenproof instance.
     * @return oldAddress The previous address of the claims revocation registry.
     */
    function setClaimRevocationRegistry(address newAddress) internal onlyOwner returns (address oldAddress) {
        if (newAddress == address(0)) {
            revert UpdateAddressError("Revocation Registry: null address");
        }

        ClaimManagerStorage storage claimStore = getStorage();

        if (claimStore.claimsRevocationRegistry == newAddress) {
            revert UpdateAddressError("Revocation Registry: Same address");
        }

        oldAddress = claimStore.claimsRevocationRegistry;
        claimStore.claimsRevocationRegistry = newAddress;
    }

    /**
     * @notice checkEnrolledIssuer verifies that an operator is correctly enrolled as an issuer
     * @dev This function reverts if the operator does not have the issuer role
     * @param operator Address of the operator whose issuer role credential is checked.
     */
    function checkEnrolledIssuer(address operator) internal view {
        Role memory issuerRole = getStorage().issuerRole;

        bool isIssuer = hasRole(operator, issuerRole.name, issuerRole.version);

        if (!isIssuer) {
            revert NotEnrolledIssuer(operator);
        }
    }

    /**
     * @notice checkEnrolledRevoker verifies that an operator is correctly enrolled as a revoker
     * @dev This function reverts if the operator does not have the revoker role
     * @param operator Address of the operator whose revoker role credential is checked.
     */
    function checkEnrolledRevoker(address operator) internal view {
        Role memory revokerRole = getStorage().revokerRole;

        bool isRevoker = hasRole(operator, revokerRole.name, revokerRole.version);

        if (!isRevoker) {
            revert NotEnrolledRevoker(operator);
        }
    }

    /**
     * @notice checkEnrolledApprover verifies that an operator is correctly enrolled as an approver
     * @dev This function reverts if the operator does not have the approver role
     * @param operator Address of the operator whose approver role credential is checked.
     */
    function checkEnrolledApprover(address operator) internal view {
        Role memory approverRole = getStorage().approverRole;

        bool isApprover = hasRole(operator, approverRole.name, approverRole.version);

        if (!isApprover) {
            revert NotEnrolledApprover(operator);
        }
    }

    /**
     * @notice checkEnrolledClaimer verifies that an operator is correctly enrolled as a claimer
     * @dev This function reverts if the operator does not have the claimer role
     * @param operator Address of the operator whose claimer role credential is checked.
     */
    function checkEnrolledClaimer(address operator) internal view {
        Role memory claimerRole = getStorage().claimerRole;

        bool isClaimer = hasRole(operator, claimerRole.name, claimerRole.version);

        if (!isClaimer) {
            revert NotEnrolledClaimer(operator);
        }
    }

    /**
     * @notice checkEnrolledWorker verifies that an operator is correctly enrolled as a worker
     * @dev This function reverts if the operator does not have the worker role
     * @param operator Address of the operator whose worker role credential is checked.
     */
    function checkEnrolledWorker(address operator) internal view {
        Role memory workerRole = getStorage().workerRole;

        bool isWorker = hasRole(operator, workerRole.name, workerRole.version);

        if (!isWorker) {
            revert NotEnrolledWorker(operator);
        }
    }

    /**
     * @notice checkRevokedWorker verifies that an operator's worker role has been correctly revoked
     * @dev This function reverts if the operator has the worker role
     * @param operator Address of the operator whose worker role credential is checked.
     */
    function checkRevokedWorker(address operator) internal view {
        Role memory workerRole = getStorage().workerRole;

        bool isWorker = hasRole(operator, workerRole.name, workerRole.version);

        if (isWorker) {
            revert NotRevokedWorker(operator);
        }
    }

    /**
     * @dev function that checks if the caller is the contract owner.
     * @custom:throws NotAuthorized error with the tag "Owner" if the caller is not the contract owner.
     */
    function checkOwnership() internal view {
        if (OwnableStorage.layout().owner != msg.sender) {
            revert NotAuthorized("Owner", msg.sender);
        }
    }

    /**
     * @notice hasRole - checks if an address has a specific role with a specific version
     * @param subject The address to check.
     * @param role The name of the role to check for.
     * @param version The version of the role to check for.
     * @return true if the `subject` is enrolled to the `role` role and with the `version` version, false otherwise
     */
    function hasRole(address subject, bytes32 role, uint256 version) internal view returns (bool) {
        ClaimManagerStorage storage claimStore = getStorage();

        // ExtCall : Contract deployed and managed by EnergyWeb Foundation
        bool isSubjectEnrolled = IClaimManager(claimStore.claimManagerAddress).hasRole(subject, role, version);
        bool isRoleRevoked = IClaimManager(claimStore.claimsRevocationRegistry).isRevoked(role, subject);

        return (isSubjectEnrolled && !isRoleRevoked);
    }

    /**
     * @dev retrieve the storage of the contract
     * @return claimStore - the pointer to the ClaimManagerStorage slot position
     */
    function getStorage() internal pure returns (ClaimManagerStorage storage claimStore) {
        bytes32 position = _CLAIM_MANAGER_STORAGE_POSITION;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            claimStore.slot := position
        }
    }
}
