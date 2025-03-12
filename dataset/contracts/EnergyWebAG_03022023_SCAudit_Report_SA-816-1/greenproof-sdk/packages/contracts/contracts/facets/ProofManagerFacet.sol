// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {LibIssuer} from "../libraries/LibIssuer.sol";
import {IProofIssuer} from "../interfaces/IProofIssuer.sol";
import {LibMetaToken} from "../libraries/LibMetaToken.sol";
import {IProofManager} from "../interfaces/IProofManager.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";
import {LibProofManager} from "../libraries/LibProofManager.sol";
import {ERC1155EnumerableInternal} from "@solidstate/contracts/token/ERC1155/enumerable/ERC1155EnumerableInternal.sol";

/**
 * @title ProofManagerFacet - A Proof managager component of the the GreenProof core module
 * @author Energyweb Foundation
 * @notice  This facet handles certificates life cycle: claims, revocation, queries and verification
 */
contract ProofManagerFacet is IProofManager, ERC1155EnumerableInternal {
    modifier onlyRevoker() {
        LibClaimManager.checkEnrolledRevoker(msg.sender);
        _;
    }

    /**
     * @notice modifier that restricts the execution of functions only to users enrolled as Claimer
     * @dev this modifer reverts the transaction if the msg.sender is not an enrolled Claimer
     */
    modifier onlyClaimer() {
        LibClaimManager.checkEnrolledClaimer(msg.sender);
        _;
    }

    /**
     * @notice claimProofFor - Claims a green certificate on behalf of an owner
     * @param certificateID ID of the certificate to claim
     * @param owner Address of the certificate owner
     * @param amount Amount of energy to claim
     */
    function claimProofFor(uint256 certificateID, address owner, uint256 amount) external onlyClaimer {
        _claimProofFor(certificateID, owner, amount);
    }

    function claimBatchProofsFor(DelegetatedClaimRequest[] memory claimRequests) external onlyClaimer {
        uint256 nbRequests = claimRequests.length;
        LibIssuer.checkBatchClaimSize(nbRequests);
        for (uint256 i; i < nbRequests; i++) {
            _claimProofFor(claimRequests[i].certificateID, claimRequests[i].certificateOwner, claimRequests[i].amount);
        }
    }

    /**
     * @notice claimProof - Claims a precise amount of certificate
     * @param certificateID - ID of the certificate to claim
     * @param amount - Amount of energy to claim
     */
    function claimProof(uint256 certificateID, uint256 amount) external {
        _claimProofFor(certificateID, msg.sender, amount);
    }

    /**
     * @notice claimBatchProofs - Claims a batch of certificates
     * @dev This function reverts if any claimedProof is already revoked
     * @dev This function reverts if any claimed amount is superior than the claimer balance
     * @param claimRequests - list of certificateIDs and amounts to claim
     */
    function claimBatchProofs(ClaimRequest[] memory claimRequests) external {
        uint256 nbRequests = claimRequests.length;
        LibIssuer.checkBatchClaimSize(nbRequests);
        for (uint256 i; i < nbRequests; i++) {
            _claimProofFor(claimRequests[i].certificateID, msg.sender, claimRequests[i].amount);
        }
    }

    /**
     * @notice revokeProof - Revokes a certificate
     * @dev This function emits the `ProofRevoked` event
     * @dev This function reverts if the certificate is already revoked or if the msg.sender is not an enrolled revoker
     * @param certificateID ID of the certificate to revoke
     */
    function revokeProof(uint256 certificateID) external {
        _revokeProof(certificateID);
    }

    /**
     * @notice revokeBatchProofs - Revokes a batch of certificates
     * @dev This function emits the `ProofRevoked` event
     * @dev This function reverts if any certificate is already revoked or if the msg.sender is not an enrolled revoker
     * @param certificateIDs - IDs of the certificates to revoke
     */
    function revokeBatchProofs(uint256[] memory certificateIDs) external {
        uint256 nbCertificates = certificateIDs.length;
        LibIssuer.checkBatchRevocationSize(nbCertificates);

        for (uint256 i; i < nbCertificates; i++) {
            _revokeProof(certificateIDs[i]);
        }
    }

    /**
     * @notice getProof - Retrieves a certificate
     * @param certificateID - ID of the certificate to retrieve
     * @return proof - IProofIssuer.Certificate memory proof
     */
    function getProof(uint256 certificateID) external view returns (IProofIssuer.Certificate memory proof) {
        LibProofManager.checkProofExistence(certificateID);
        proof = LibIssuer.getProof(certificateID);
    }

    /**
     * @notice getProofIdByDataHash - Retrieves the ID of a green certificate by its data hash
     * @param dataHash - Data hash of the certificate
     * @return proofId - The certificate ID
     */
    function getProofIdByDataHash(bytes32 dataHash) external view returns (uint256 proofId) {
        return LibIssuer.getProofIdByDataHash(dataHash);
    }

    /**
     * @notice getProofIDsByDataHashes - Retrieves the IDs of a batch of green certificates by their data hashes
     * @param dataHashes - Data hashes of the certificates
     * @return dataToCertificateIds - The list of hashes-certificate IDs mappings
     */
    function getProofIDsByDataHashes(bytes32[] memory dataHashes) external view returns (CertifiedData[] memory dataToCertificateIds) {
        uint256 nbDataHashes = dataHashes.length;
        dataToCertificateIds = new CertifiedData[](nbDataHashes);

        for (uint256 i; i < nbDataHashes; i++) {
            dataToCertificateIds[i] = CertifiedData({dataHash: dataHashes[i], certificateID: LibIssuer.getProofIdByDataHash(dataHashes[i])});
        }
    }

    /**
     * @notice getProofsOf - Retrieves all certificates of a user
     * @dev This function reverts if the user has no certificates
     * @param userAddress - Address of the user
     * @return The list of all certificates owned by the userAddress
     */
    function getProofsOf(address userAddress) external view returns (IProofIssuer.Certificate[] memory) {
        uint256[] memory userTokenList = _tokensByAccount(userAddress);
        uint256 numberOfCertificates = userTokenList.length;

        LibProofManager.checkOwnedCertificates(numberOfCertificates, userAddress);

        IProofIssuer.Certificate[] memory userProofs = new IProofIssuer.Certificate[](numberOfCertificates);
        for (uint256 i; i < numberOfCertificates; i++) {
            uint256 currentTokenID = userTokenList[i];
            uint256 volume = _balanceOf(userAddress, currentTokenID);
            userProofs[i] = LibIssuer.getCertificate(currentTokenID, volume);
        }

        return userProofs;
    }

    /**
     * @notice claimedBalanceOf - Retrieves the volume of certificate ID claimed by a user
     * @param user - Address of the user
     * @param certificateID - ID of the certificate
     * @return The effective volume claimed by the user on for this certificateID
     */
    function claimedBalanceOf(address user, uint256 certificateID) external view returns (uint256) {
        return LibIssuer.claimedBalanceOf(user, certificateID);
    }

    /**
     * @notice verifyProof - Verifies that a proof is part of a Merkle tree
     * @dev The verification of a proof is made using Openzeppelin's Merkle trees verification (https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof)
     * @param rootHash - root hash of the of the merkle tree representing the data to certify
     * @param leaf - leaf of the merkle tree representing the data to certify
     * @param proof - the proof being verified
     * @return true if the proof is valid, false otherwise
     */
    function verifyProof(bytes32 rootHash, bytes32 leaf, bytes32[] memory proof) external pure returns (bool) {
        return LibProofManager.verifyProof(rootHash, leaf, proof);
    }

    /**
     * @notice _claimProofFor - Claims a green certificate on behalf of an owner
     * @dev This function reverts if the claimedProof is revoked
     * @dev This function reverts if the claimed amount is superior than the claimer balance
     * @dev On successful claim, this function emits the `ProofClaimed` event
     * @param certificateID ID of the certificate to claim
     * @param owner Address of the certificate owner
     * @param amount Amount of energy to claim
     */
    function _claimProofFor(uint256 certificateID, address owner, uint256 amount) private {
        uint256 ownedBalance = _balanceOf(owner, certificateID);

        LibProofManager.checkClaimableProof(certificateID, owner, amount, ownedBalance);

        LibIssuer.registerClaimedProof(certificateID, owner, amount);
        _burn(owner, certificateID, amount);

        /* solhint-disable-next-line not-rely-on-time */
        emit ProofClaimed(certificateID, owner, block.timestamp, amount);
    }

    /**
     * @notice _revokeProof - Revokes a certificate
     * @dev This function emits the `ProofRevoked` event
     * @dev This function reverts if the certificate is already revoked or if the msg.sender is not an enrolled revoker
     * @param certificateID ID of the certificate to revoke
     */
    function _revokeProof(uint256 certificateID) private onlyRevoker {
        LibProofManager.checkProofRevocability(certificateID);
        LibProofManager.revokeProof(certificateID);
        emit ProofRevoked(certificateID);
        bool isMetacertificateEnabled = LibMetaToken.getStorage().isMetaCertificateEnabled;

        if (isMetacertificateEnabled && LibMetaToken.totalSupply(certificateID) > 0) {
            LibMetaToken.revokeMetaToken(certificateID);
        }
    }
}
