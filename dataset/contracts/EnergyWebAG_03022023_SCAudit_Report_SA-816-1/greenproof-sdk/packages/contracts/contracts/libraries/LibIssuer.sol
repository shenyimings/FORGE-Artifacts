//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {LibClaimManager} from "./LibClaimManager.sol";
import {LibProofManager} from "./LibProofManager.sol";
import {IProofIssuer} from "../interfaces/IProofIssuer.sol";
import {UintUtils} from "@solidstate/contracts/utils/UintUtils.sol";
import {IERC1155} from "@solidstate/contracts/interfaces/IERC1155.sol";

import {ERC1155BaseStorage} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol";

/**
 * @title LibIssuer
 * @dev Library for storing and managing green proof certificates
 * @author Energyweb Foundation
 * @notice This contract is a library for green proof certificates management
 */

library LibIssuer {
    /**
     * @dev Structure storing the configuration of the contract's owner
     */
    struct BatchConfig {
        uint256 batchIssuanceSize;
        uint256 batchTransferSize;
        uint256 batchClaimingSize;
        uint256 batchRevocationSize;
    }

    /**
     * @notice Certificate registry tracking issued certificates
     * @dev The certificate registry is represented by this storage structure
     * @custom:field name - name of the certificate
     * @custom:field symbol - symbol of the certificate
     * @custom:field batchQueueSize - size of the batch queue
     * @custom:field latestCertificateId - latest issued certificate ID
     * @custom:field revocablePeriod - revocable period for certificates
     * @custom:field dataToCertificateID - mapping of data hash to certificate ID
     * @custom:field certificates - mapping of certificate ID to certificate information
     * @custom:field claimedBalances - mapping of certificate ID to account balances, to track how much of a certificate ID a wallet has claimed
     * @custom:field disclosedData - mapping of data hash to mapping of key-value pairs of disclosed data
     * @custom:field isDataDisclosed - mapping of data hash to mapping of keys to booleans indicating whether the data has been disclosed for that key
     * @custom:field voteToCertificates - mapping of vote ID to mapping of data hash to certificate ID
     */
    struct IssuerStorage {
        string name;
        string symbol;
        uint256 batchIssuanceSize;
        uint256 batchTransferSize;
        uint256 batchClaimingSize;
        uint256 batchRevocationSize;
        uint256 revocablePeriod;
        uint256 latestCertificateId;
        mapping(bytes32 => uint256) dataToCertificateID;
        mapping(uint256 => IProofIssuer.Certificate) certificates;
        // Mapping from token ID to account balances, to track how much of certificate ID a wallet has claimed
        mapping(uint256 => mapping(address => uint256)) claimedBalances;
        mapping(bytes32 => mapping(string => string)) disclosedData;
        //checks that data is disclosed for a specific key (string) of a precise certificate (bytes32)
        mapping(bytes32 => mapping(string => bool)) isDataDisclosed;
        // @notice saving the data needed for future features
        mapping(bytes32 => mapping(bytes32 => uint256)) voteToCertificates;
    }

    /**
     * @dev Tracking the storage position of the issuerStorage
     */
    bytes32 private constant _ISSUER_STORAGE_POSITION = keccak256("ewc.greenproof.issuer.diamond.storage");

    /**
     * @notice ProofMinted event emitted when a new green proof certificate is minted
     * @param certificateID ID of the minted certificate
     * @param volume volume of the minted certificate
     * @param receiver address of the receiver of the minted certificate
     */
    event ProofMinted(uint256 indexed certificateID, uint256 indexed volume, address indexed receiver);

    /**
     * @dev Error: Zero address passed as receiver
     */
    error ForbiddenZeroAddressReceiver();

    /**
     * @dev Error: Data hash has already been certified
     * @param dataHash hash of the data associated with the certificate
     */
    error AlreadyCertifiedData(bytes32 dataHash);

    /**
     * @dev ForbiddenSelfApproval: raised when an approver user tries to approve set transfer approval for self
     * @param approver address of the operator to grant transfer rights for
     * @param certificateOwner owner on the belhalf the approver want to be allowed for certificates transfers
     */
    error ForbiddenSelfApproval(address approver, address certificateOwner);

    /**
     * @dev AlreadyApprovedOperator: raised when an approver tries to approve an already approved operator for transfers
     * @param operator address of the operator to grant transfer rights for
     * @param certificateOwner owner on the belhalf the operator has been allowed for certificates transfers
     */
    error AlreadyApprovedOperator(address operator, address certificateOwner);
    /**
     * @dev AlreadyRemovedOperator: raised when an approver tries to removed an already removed operator for transfers
     * @param operator address of the operator to revoke transfer rights for
     * @param certificateOwner owner on the belhalf the operator has been revoked for certificates transfers
     */
    error AlreadyRemovedOperator(address operator, address certificateOwner);

    /**
     * @dev Error: Data has already been disclosed for a specific key
     * @param dataHash hash of the data associated with the certificate
     * @param key key of the data being disclosed
     */
    error AlreadyDisclosedData(bytes32 dataHash, string key);

    /**
     * @dev Error: Volume is not in consensus
     * @param volume volume of the certificate
     * @param dataHash hash of the data associated with the certificate
     */
    error VolumeNotInConsensus(uint256 volume, bytes32 dataHash);

    /**
     * @dev Error: Transfer not allowed
     * @param certificateID ID of the certificate
     * @param sender address of the sender of the certificate
     * @param receiver address of the receiver of the certificate
     */
    error NotAllowedTransfer(uint256 certificateID, address sender, address receiver);

    /**
     * @dev Error: reverts when the user is neither the owner of the certificate nor approved
     * @param operator address of the operator trying to trasnfer the certificate
     * @param owner address of the owner of the certificate
     */
    error NotOwnerOrApproved(address operator, address owner);

    error BatchQueueSizeExceeded(uint256 batchQueueSize, uint256 batchQueueSizeLimit);

    /**
     * @dev Initialize the contract with a revocable period for certificates
     * @param revocablePeriod period in which the certificates can be revoked
     */
    function init(uint256 revocablePeriod, BatchConfig memory batchCfg) internal {
        getStorage().revocablePeriod = revocablePeriod;
        getStorage().batchIssuanceSize = batchCfg.batchIssuanceSize;
        getStorage().batchTransferSize = batchCfg.batchTransferSize;
        getStorage().batchClaimingSize = batchCfg.batchClaimingSize;
        getStorage().batchRevocationSize = batchCfg.batchRevocationSize;
    }

    /**
     * @dev Increment the latest certificate ID
     */
    function incrementAndGetProofIndex() internal returns (uint256) {
        getStorage().latestCertificateId++;
        return getLatestCertificateId();
    }

    /**
     * @dev Records a new green proof certificate into the certificate registry
     * @param dataHash hash of the data associated to the certificate
     * @param generatorAddress address of the generator of the certificate
     * @param volumeInWei volume of the certificate in wei
     * @param certificateID ID of the certificate
     * @param voteID ID of the vote associated to the certificate
     */
    function registerProof(bytes32 dataHash, address generatorAddress, uint256 volumeInWei, uint256 certificateID, bytes32 voteID) internal {
        LibIssuer.IssuerStorage storage issuer = getStorage();

        issuer.certificates[certificateID] = IProofIssuer.Certificate({
            isRevoked: false,
            certificateID: certificateID,
            issuanceDate: block.timestamp, // solhint-disable-line not-rely-on-time
            volume: volumeInWei,
            merkleRootHash: dataHash,
            generator: generatorAddress
        });
        issuer.dataToCertificateID[dataHash] = certificateID;
        issuer.voteToCertificates[voteID][dataHash] = certificateID;
    }

    /**
     * @dev Register a claimed green proof certificate
     * @param certificateID ID of the claimed certificate
     * @param user address of the user claiming the certificate
     * @param claimedAmount amount of the certificate being claimed
     */
    function registerClaimedProof(uint256 certificateID, address user, uint256 claimedAmount) internal {
        getStorage().claimedBalances[certificateID][user] += claimedAmount;
    }

    /**
     * @notice Disclose data associated with a green proof certificate
     * @param dataHash hash of the data associated with the certificate
     * @param key key of the data being disclosed
     * @param value value of the data being disclosed
     */
    function discloseData(bytes32 dataHash, string memory key, string memory value) internal {
        LibIssuer.IssuerStorage storage issuer = getStorage();

        issuer.disclosedData[dataHash][key] = value;
        issuer.isDataDisclosed[dataHash][key] = true;
    }

    /**
     * @notice approveFor - Grants approval to the operator to transfer certificates owned by another wallet.
     * @param certificateOwner address of the account owning the certificate to be transferred
     * @param operator address of the account to be granted approval
     * @param shouldBeApproved status of the approval to set
     * @dev when the approval is being set to true, `msg.sender` cannot be the same as `operator`
     */
    function setApprovalFor(address certificateOwner, address operator, bool shouldBeApproved) internal {
        if (shouldBeApproved && msg.sender == operator) {
            revert ForbiddenSelfApproval(msg.sender, certificateOwner);
        }
        ERC1155BaseStorage.layout().operatorApprovals[certificateOwner][operator] = shouldBeApproved;
    }

    /**
     * @notice preventAlreadyApproved - Prevents an operator from being approved twice for the given certificate owner.
     * @param operator The address of the operator to check.
     * @param certificateOwner The address of the certificate owner to check.
     * @dev If the operator is already approved, the function will revert.
     */
    function preventAlreadyApproved(address operator, address certificateOwner) internal view {
        bool isOperatorApproved = ERC1155BaseStorage.layout().operatorApprovals[certificateOwner][operator];

        if (isOperatorApproved) {
            revert AlreadyApprovedOperator(operator, certificateOwner);
        }
    }

    /**
     * @notice preventAlreadyRemovedOperator - Prevents an operator from being removed twice for the given certificate owner.
     * @param operator The address of the operator to check.
     * @param certificateOwner The address of the certificate owner to check.
     * @dev If the operator transfer's right is already removed, the function will revert.
     */
    function preventAlreadyRemovedOperator(address operator, address certificateOwner) internal view {
        bool isOperatorApproved = ERC1155BaseStorage.layout().operatorApprovals[certificateOwner][operator];

        if (isOperatorApproved == false) {
            revert AlreadyRemovedOperator(operator, certificateOwner);
        }
    }

    /**
     * @notice Checks if a certificate with a specific data hash has already been issued
     * @dev This prevents duplicate issuance of the same certificate ID
     * @param data hash of the data associated with the certificate
     */
    function preventAlreadyCertified(bytes32 data) internal view {
        IssuerStorage storage issuer = getStorage();
        uint256 certificateId = issuer.dataToCertificateID[data];

        if (certificateId != 0 && !isCertificateRevoked(certificateId)) {
            revert AlreadyCertifiedData(data);
        }
    }

    /**
     * @dev Get a specific green proof certificate
     * @param certificateID ID of the certificate
     * @param volumeInWei volume of the certificate in wei
     */
    function getCertificate(uint256 certificateID, uint256 volumeInWei) internal view returns (IProofIssuer.Certificate memory) {
        IssuerStorage storage issuer = getStorage();

        return
            IProofIssuer.Certificate({
                isRevoked: issuer.certificates[certificateID].isRevoked,
                certificateID: issuer.certificates[certificateID].certificateID,
                issuanceDate: issuer.certificates[certificateID].issuanceDate,
                volume: volumeInWei,
                merkleRootHash: issuer.certificates[certificateID].merkleRootHash,
                generator: issuer.certificates[certificateID].generator
            });
    }

    /**
     * @notice Checks if a certificate has been revoked
     * @param certificateID ID of the certificate
     * @return true if the certificate has been revoked, false otherwise
     */
    function isCertificateRevoked(uint256 certificateID) internal view returns (bool) {
        return getStorage().certificates[certificateID].isRevoked;
    }

    function checkNotDisclosed(bytes32 dataHash, string memory key) internal view {
        if (getStorage().isDataDisclosed[dataHash][key]) {
            revert AlreadyDisclosedData(dataHash, key);
        }
    }

    /**
     * @notice checkApprovedSender - Checks if the operator is approved to send certificates on behalf of the owner.
     *
     * @param from The address of the owner of the certificates.
     * @param operator The address of the operator whose approval is being checked.
     *
     * @dev reverts with `NotOwnerOrApproved` error if the operator is neither approved nor the owner of certificate nor enrolled with transfer Role.
     */
    function checkApprovedSender(address from, address operator) internal view {
        bool isApproved = IERC1155(address(this)).isApprovedForAll(from, operator);

        if (!isApproved && from != operator) {
            revert NotOwnerOrApproved(operator, from);
        }
    }

    /**
     * @notice checkAllowedTransfer - Checks if a transfer of a certificate is allowed
     * @notice revoked certificate should not be transferred, unless the receiver is the generator address
     * @dev reverts if the transferred certificates is revoke AND the receiver is not the generator
     * @param certificateID ID of the certificate being transferred
     * @param receiver address of the receiver of the certificate
     */
    function checkAllowedTransfer(uint256 certificateID, address receiver) internal view {
        if (isCertificateRevoked(certificateID) && receiver != getStorage().certificates[certificateID].generator) {
            revert NotAllowedTransfer(certificateID, msg.sender, receiver);
        }
    }

    /**
     * @notice checkBatchIssuanceSize - Checks if the issuance batch queue size is not exceeded
     * @dev reverts if the issuance batch queue size is exceeded
     * @param queueSize size of the issuance batch queue to check
     */
    function checkBatchIssuanceSize(uint256 queueSize) internal view {
        uint256 allowedBatchSize = getStorage().batchIssuanceSize;
        if (queueSize > allowedBatchSize) {
            revert BatchQueueSizeExceeded(queueSize, allowedBatchSize);
        }
    }

    /**
     * checkBatchTransferSize - Checks if the transfer batch queue size is not exceeded
     * @dev reverts if the transfer batch queue size is exceeded
     * @param queueSize size of the batch queue to check
     */
    function checkBatchTransferSize(uint256 queueSize) internal view {
        uint256 allowedBatchSize = getStorage().batchTransferSize;
        if (queueSize > allowedBatchSize) {
            revert BatchQueueSizeExceeded(queueSize, allowedBatchSize);
        }
    }

    /**
     * @notice checkBatchClaimSize - Checks if the claim batch queue size is not exceeded
     * @dev reverts if the claim batch queue size is exceeded
     * @param queueSize size of the batch queue to check
     */
    function checkBatchClaimSize(uint256 queueSize) internal view {
        uint256 allowedBatchSize = getStorage().batchClaimingSize;
        if (queueSize > allowedBatchSize) {
            revert BatchQueueSizeExceeded(queueSize, allowedBatchSize);
        }
    }

    /**
     * @notice checkBatchRevocationSize - Checks if the revocation batch queue size is not exceeded
     * @dev reverts if the revocation batch queue size is exceeded
     * @param queueSize size of the batch queue to check
     */
    function checkBatchRevocationSize(uint256 queueSize) internal view {
        uint256 allowedBatchSize = getStorage().batchRevocationSize;
        if (queueSize > allowedBatchSize) {
            revert BatchQueueSizeExceeded(queueSize, allowedBatchSize);
        }
    }

    /**
     *@notice claimedBalanceOf  - returns the amount volume of certifcates ID claimed by a user
     * @param user - The user for whom we check claimed balance for
     * @param certificateID - ID of the greenproof certificate
     */
    function claimedBalanceOf(address user, uint256 certificateID) internal view returns (uint256) {
        return getStorage().claimedBalances[certificateID][user];
    }

    /**
     * @notice getProof - Retrieves a certificate
     * @param certificateID - ID of the certificate to retrieve
     * @return proof - The greenproof certificate of id `certificateID`
     */
    function getProof(uint256 certificateID) internal view returns (IProofIssuer.Certificate memory proof) {
        proof = getStorage().certificates[certificateID];
    }

    /**
     * @notice getProofIdByDataHash - Retrieves the ID of a green certificate by its data hash
     * @param dataHash - Data hash of the certificate
     * @return proofId - The certificate ID
     */
    function getProofIdByDataHash(bytes32 dataHash) internal view returns (uint256 proofId) {
        return getStorage().dataToCertificateID[dataHash];
    }

    /**
     * @notice getLatestCertificateId - Gets the id of the last certificate issued
     * @return proofId - The ID of the latest issued certificate
     */
    function getLatestCertificateId() internal view returns (uint256 proofId) {
        return getStorage().latestCertificateId;
    }

    /**
     * @notice getRevocablePeriod - Retrieves the duration under which issued certificates are revocable
     * @return revocablePeriod - the duration during which issued proofs can be revoked
     */
    function getRevocablePeriod() internal view returns (uint256 revocablePeriod) {
        return getStorage().revocablePeriod;
    }

    /**
     * @notice getTokeName - Retrieves the name of the token
     * @return name - The name of the certificate token
     */
    function getTokenName() internal view returns (string memory) {
        return getStorage().name;
    }

    /**
     * @notice getTokenSymbol - Retrieves the symbol of the token
     * @return symbol - The symbol of the certificate token
     */
    function getTokenSymbol() internal view returns (string memory) {
        return getStorage().symbol;
    }

    /**
     * @dev Get the hash representation of the volume key-value pair inside the data to certify
     * @return volumeHash
     */
    function getAmountHash(uint256 volume) internal pure returns (bytes32 volumeHash) {
        string memory volumeString = UintUtils.toString(volume);
        volumeHash = keccak256(abi.encodePacked("volume", volumeString));
    }

    /**
     * @notice preventZeroAddressReceiver - Prevents the receiver address from being the zero address
     * @dev tthis prevent certificates loss by reverting if the receiver address is the zero address
     * @param receiver address of the receiver of the certificate
     */
    function preventZeroAddressReceiver(address receiver) internal pure {
        if (receiver == address(0)) {
            revert ForbiddenZeroAddressReceiver();
        }
    }

    /**
     * @notice checkVolumeValidity - Checks if the volume of the certificate is in consensus
     * @dev This function reverts if provided volume is not part of the merkle root hash reprensenting certified data
     * @param volume volume of the certificate
     * @param dataHash hash of the data associated to the certificate
     * @param amountProof proof of the volume of the certificate
     */
    function checkVolumeValidity(uint256 volume, bytes32 dataHash, bytes32[] memory amountProof) internal pure {
        bytes32 volumeHash = getAmountHash(volume);

        bool isVolumeInConsensus = LibProofManager.verifyProof(dataHash, volumeHash, amountProof);
        if (!isVolumeInConsensus) {
            revert VolumeNotInConsensus(volume, dataHash);
        }
    }

    /**
     * @dev Get the storage for the issuer library
     * @return issuerStorage - The pointer to the issuerStorage slot position
     */
    function getStorage() internal pure returns (IssuerStorage storage issuerStorage) {
        bytes32 position = _ISSUER_STORAGE_POSITION;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            issuerStorage.slot := position
        }
    }
}
