// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title IProofIssuer
 * @dev Interface for a green certificate issuance and validation system
 * @author EnergyWeb Foundation
 */
interface IProofIssuer {
    /**
     * @notice Certificate - Struct representing a green certificate
     * @custom:field isRevoked - flag indicating if the certificate has been revoked
     * @custom:field certificateID - ID of the certificate
     * @custom:field issuanceDate - Date of issuance of the certificate
     * @custom:field volume - amount of minted tokens for the certificate
     * @custom:field merkleRootHash - Merkle root hash of the certified data
     * @custom:field generator - Address of the generator
     */
    struct Certificate {
        bool isRevoked;
        uint256 certificateID;
        uint256 issuanceDate;
        uint256 volume;
        bytes32 merkleRootHash;
        address generator;
    }

    /**
     * @notice IssuanceRequest - Struct representing a request for certificate issuance
     * @custom:field volume - amount of minted tokens for the certificate
     * @custom:field voteID - ID of the vote
     * @custom:field dataHash - Merkle root hash of the certified data
     * @custom:field dataProof - Merkle proof of the certified data
     * @custom:field amountProof - Merkle proof of the amount
     * @custom:field generator - Address of the generator
     * @custom:field tokenUri - URI of the token
     */
    struct IssuanceRequest {
        uint256 volume;
        bytes32 voteID;
        bytes32 dataHash;
        bytes32[] dataProof;
        bytes32[] amountProof;
        address generator;
        string tokenUri;
    }

    /**
     * @notice TransferRequest - Struct representing a request for certificate transfer
     * @custom:field sender - Address of the sender of the certificate
     * @custom:field recipient - Address of the recipient of the certificate
     * @custom:field certificateID - ID of the certificate
     * @custom:field amount - Amount of tokens to be transferred
     * @custom:field data - Data payload to be passed to the transaction
     */
    struct TransferRequest {
        address sender;
        address recipient;
        uint256 certificateID;
        uint256 amount;
        bytes data;
    }

    /**
     * @notice TransferBatchRequest - Struct representing a request for certificate batch transfer
     * @custom:field sender - Address of the sender of the certificate
     * @custom:field recipient - Address of the recipient of the certificate
     * @custom:field certificateIDs - IDs of all certificates to transfer
     * @custom:field amounts - Amounts of certificate tokens to be transferred
     * @custom:field data - Data payload to be passed to the transaction
     */
    struct TransferBatchRequest {
        address sender;
        address recipient;
        uint256[] certificateIDs;
        uint256[] amounts;
        bytes data;
    }

    /**
     *  @notice ProofMinted - Event emitted when a proof is minted
     *  @param certificateID - unique identifier for the proof
     *  @param volume - certified volume
     *  @param receiver -  address of the receiver of the proof
     */
    event ProofMinted(uint256 indexed certificateID, uint256 indexed volume, address indexed receiver);

    /**
     * @notice OperatorApproved - Event emitted when an operator is approved for a certificate owner.
     * @param operator The address of the operator that was approved.
     * @param certificateOwner The address of the certificate owner for whom the operator is approved.
     * @param approver The address of the authorized approver that approved the operator.
     */
    event OperatorApproved(address indexed operator, address indexed certificateOwner, address indexed approver);

    /**
     * @notice OperatorRemoved - Event emitted when transfer rights of an operator has been revoked for a certificate owner.
     * @param operator The address of the operator that was removed.
     * @param certificateOwner The address of the certificate owner for whom the operator is revoked.
     * @param approver The address of the authorized approver that removed the operator.
     */
    event OperatorRemoved(address indexed operator, address indexed certificateOwner, address indexed approver);

    /**
     * @notice `requestProofIssuance` - An authorized issuer requests proof issuance after a consensus is reached.
     * This runs the automatic data verification and the certificate minting process.
     * @param request - An IssuanceRequest struct containing the data needed to issue a certificate.
     */
    function requestProofIssuance(IssuanceRequest memory request) external;

    /**
     * @notice `requestBatchIssuance` - An authorized issuer requests issuance of a bacth of certificates.
     * @param requestQueue - An array of IssuanceRequest struct containing the data needed to issue a certificate.
     * @dev This function is used to issue a batch of certificates after a consensus is reached.
     * @dev The MerkleProof verification uses the `merkleProof` library provided by openzeppelin/contracts -> https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof.
     * @dev The generator address can not be the zero address
     */
    function requestBatchIssuance(IssuanceRequest[] memory requestQueue) external;

    /**
     * @notice `simpleBatchTransfer` - An authorized operator requests transfer of a single batch of certificates.
     * @param transferRequestsList - An array of TransferRequest struct containing the data needed to transfer one certificate for each request.
     */
    function simpleBatchTransfer(TransferRequest[] memory transferRequestsList) external;

    /**
     * @notice `multipleBatchTransfer` - An authorized operator requests transfer of multiple batches of certificates.
     * @param transferBatchRequests - An array of TransferBatchRequest struct containing the data needed to transfer multiple certificates for each request.
     */
    function multipleBatchTransfer(TransferBatchRequest[] memory transferBatchRequests) external;

    /**
     * @notice `discloseData` - Publicly exposes specific a information of the certified data.
     * This information is a key-value pair composing the dataHash merkleTree
     * @param key - the key referencing the information inside the certified data set
     * @param value - the actual value of the information
     * @param dataProof - The proofs path to verify that key-value hashed data is part of dataHash merkleTree
     * @param dataHash - The merkleRoot hash of the certified data set.
     */
    function discloseData(string memory key, string memory value, bytes32[] memory dataProof, bytes32 dataHash) external;

    /**
     * @notice approveOperator -  Grants approval to an operator to transfer certificates of a specific certificate owner
     * @param operator The address of the operator being approved
     * @param certificateOwner The address of the certificate owner for whom the operator is being approved
     * @dev If the operator is already approved, the function will revert.
     * @dev If the caller of this function does not have the `approver` role, the function will revert.
     * @dev `msg.sender` cannot be the same as `operator`
     */
    function approveOperator(address operator, address certificateOwner) external;

    /**
     * @notice removeApprovedOperator -  revoke approval of an operator to transfer certificates of a specific certificate owner
     * @param operator The address of the operator being revoked
     * @param certificateOwner address of the user for whom the operator is being revoked transfer rights
     * @dev If transfer rights of operator has already been removed for this certificate owner, the function will revert.
     * @dev If the caller of this function does not have the `approver` role, the function will revert.
     */
    function removeApprovedOperator(address operator, address certificateOwner) external;

    /**
     * @notice `getCertificateOwners` - Get the listing of all the wallets which hold a share of a specific certificate
     * @param certificateID - the id of the minted certificate
     * @return certificateOwners - The List of all users / wallets holding a share of this `certificateID`.
     */
    function getCertificateOwners(uint256 certificateID) external view returns (address[] memory);
}
