// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IProofIssuer} from "./IProofIssuer.sol";

/**
 * @title IProofManager
 * @dev Interface for managing green certificates
 * @author EnergyWeb Foundation
 */
interface IProofManager {
    /**
     * @notice ClaimRequest - Struct representing a request for certificate claim
     * @custom:field amount - Amount of tokens to be claimed
     * @custom:field certificateID - ID of the certificate
     */
    struct ClaimRequest {
        uint256 amount;
        uint256 certificateID;
    }

    /**
     * @notice DelegetatedClaimRequest - Struct representing a request for certificate claim on behalf of an owner
     * @custom:field amount - Amount of tokens to be claimed
     * @custom:field certificateID - ID of the certificate
     * @custom:field certificateOwner - Address of the certificate owner
     */
    struct DelegetatedClaimRequest {
        uint256 amount;
        uint256 certificateID;
        address certificateOwner;
    }

    /**
     * @notice CertifiedData - Struct representing a certified data
     * @custom:field dataHash - Hash of the certified data
     * @custom:field certificateID - ID of the certificate
     */
    struct CertifiedData {
        bytes32 dataHash;
        uint256 certificateID;
    }

    /**
     * @notice ProofRevoked - Event emitted when a certificate is revoked
     * @param certificateID - ID of the revoked certificate
     */
    event ProofRevoked(uint256 indexed certificateID);

    /**
     * @notice ProofClaimed - Event emitted when a certificate is claimed
     * @param certificateID - ID of the claimed certificate
     * @param to - Address of the claimer
     * @param timestamp - Timestamp of the claim
     * @param amount -  Amount of energy claimed
     */
    event ProofClaimed(uint256 indexed certificateID, address indexed to, uint256 indexed timestamp, uint256 amount);

    /**
     * @notice revokeProof - Revokes a certificate
     * @dev This function emits the `ProofRevoked` event
     * @dev This function reverts if the certificate is already revoked or if the msg.sender is not an enrolled revoker
     * @param certificateID ID of the certificate to revoke
     */
    function revokeProof(uint256 certificateID) external;

    /**
     * @notice revokeBatchProofs - Revokes a batch of certificates
     * @dev This function emits the `ProofRevoked` event
     * @dev This function reverts if any certificate is already revoked or if the msg.sender is not an enrolled revoker
     * @param certificateIDs - IDs of the certificates to revoke
     */
    function revokeBatchProofs(uint256[] memory certificateIDs) external;

    /**
     * @notice claimProof - Claims a precise amount of certificate
     * @dev This function reverts if the claimedProof is revoked
     * @dev This function reverts if the claimed amount is superior than the claimer balance
     * @dev On successful claim, this function emits the `ProofClaimed` event
     * @param certificateID - ID of the certificate to claim
     * @param amount - Amount of energy to claim
     */
    function claimProof(uint256 certificateID, uint256 amount) external;

    /**
     * @notice claimBatchProofs - Claims a batch of certificates
     * @dev This function reverts if any claimedProof is already revoked
     * @dev This function reverts if any claimed amount is superior than the claimer balance
     * @param claimRequests - list of certificateIDs and amounts to claim
     */
    function claimBatchProofs(ClaimRequest[] memory claimRequests) external;

    /**
     * @notice claimProofFor - Claims a green certificate on behalf of an owner
     * @param certificateID ID of the certificate to claim
     * @param owner Address of the certificate owner
     * @param amount Amount of energy to claim
     */
    function claimProofFor(uint256 certificateID, address owner, uint256 amount) external;

    /**
     * @notice getProof - Retrieves a certificate
     * @param certificateID - ID of the certificate to retrieve
     * @return proof - IProofIssuer.Certificate memory proof
     */
    function getProof(uint256 certificateID) external view returns (IProofIssuer.Certificate memory proof);

    /**
     * @notice getProofIdByDataHash - Retrieves the ID of a green certificate by its data hash
     * @param dataHash - Data hash of the certificate
     * @return proofId - The certificate ID
     */
    function getProofIdByDataHash(bytes32 dataHash) external view returns (uint256 proofId);

    /**
     * @notice getProofIDsByDataHashes - Retrieves the IDs of a batch of green certificates by their data hashes
     * @param dataHashes - Data hashes of the certificates
     * @return dataToCertificateIds - The list of hashes-certificate IDs mappings
     */
    function getProofIDsByDataHashes(bytes32[] memory dataHashes) external view returns (CertifiedData[] memory dataToCertificateIds);

    /**
     * @notice getProofsOf - Retrieves all certificates of a user
     * @dev This function reverts if the user has no certificates
     * @param userAddress -  Address of the user
     * @return The list of all certificates owned by the userAddress
     */
    function getProofsOf(address userAddress) external view returns (IProofIssuer.Certificate[] memory);

    /**
     * @notice claimedBalanceOf - Retrieves the volume of certificate ID claimed by a user
     * @param user - Address of the user
     * @param certificateID - ID of the certificate
     * @return The effective volume claimed by the user on for this certificateID
     */
    function claimedBalanceOf(address user, uint256 certificateID) external view returns (uint256);

    /**
     * @notice verifyProof - Verifies that a proof is part of a Merkle tree
     * @dev The verification of a proof is made using Openzeppelin's Merkle trees verification (https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof)
     * @param rootHash - root hash of the of the merkle tree representing the data to certify
     * @param leaf - leaf of the merkle tree representing the data to certify
     * @param proof - the proof being verified
     * @return true if the proof is valid, false otherwise
     */
    function verifyProof(bytes32 rootHash, bytes32 leaf, bytes32[] memory proof) external pure returns (bool);
}
