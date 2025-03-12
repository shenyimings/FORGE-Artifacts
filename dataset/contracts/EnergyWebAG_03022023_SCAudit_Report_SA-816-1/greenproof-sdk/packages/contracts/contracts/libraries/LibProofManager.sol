// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import {MerkleProof} from "@solidstate/contracts/cryptography/MerkleProof.sol";
import {LibIssuer} from "./LibIssuer.sol";

/**
 * @title LibProofManager
 * @author EnergyWeb Foundation
 * @notice This library manages green proofs verification
 * @dev The library includes functions to check proof existance, proof revocability, claimable proof, certificates ownership, proof validity
 * @dev The librairy uses the OpenZeppelin MerkleProof contract to verify the proofs. (https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof)
 * @custom:errors ProofRevoked, InvalidProof, NoProofsOwned, InsufficientBalance, NonExistingCertificate, NonRevokableProof.
 */
library LibProofManager {
    error ProofRevoked(uint256 certificateID);
    error InvalidProof(bytes32 rootHash, bytes32 leaf, bytes32[] proof);
    error NoProofsOwned(address user);
    error InsufficientBalance(address claimer, uint256 certificateID, uint256 claimedVolume);
    error NonExistingCertificate(uint256 certificateID);
    error TimeToRevokeElapsed(uint256 certificateID, uint256 issuanceDate, uint256 revocablePeriod);

    /**
     * @notice revokeProof - Revokes a certificate
     * @param certificateID ID of the certificate to revoke
     */
    function revokeProof(uint256 certificateID) internal {
        LibIssuer.getStorage().certificates[certificateID].isRevoked = true;
    }

    /**
     * @notice Checks if a certificate exists
     * @dev A certificate exists if certificates ID > 0 && certificates <= latestCertificateId
     * @dev this function reverts if the certificate ID does not exist
     * @param certificateID - ID of the certificate being checked
     */
    function checkProofExistence(uint256 certificateID) internal view {
        uint256 latestCertificateId = LibIssuer.getLatestCertificateId();

        if ((certificateID == 0) || (certificateID > latestCertificateId)) {
            revert NonExistingCertificate(certificateID);
        }
    }

    /**
     * @notice checkProofRevocability - Checks if a certificate is revocable
     * @dev A revocable certificate MUST exist (as existance is defined in `checkProofExistance`)
     * @dev A revocable certificate MUST not have already been revoked
     * @dev A revocable certificate MUST have been issued since a duration shorter than the revocable period
     * @dev This functions reverts if one of the above requirements is not met
     * @param certificateID - ID of the certificate being checked
     */
    function checkProofRevocability(uint256 certificateID) internal view {
        checkProofExistence(certificateID);

        if (LibIssuer.isCertificateRevoked(certificateID)) {
            revert ProofRevoked(certificateID);
        }

        uint256 issuanceDate = LibIssuer.getProof(certificateID).issuanceDate;
        uint256 revocablePeriod = LibIssuer.getRevocablePeriod();

        // checks that the issuance duration is below the revocable period
        // solhint-disable-next-line not-rely-on-time
        if (issuanceDate + revocablePeriod < block.timestamp) {
            revert TimeToRevokeElapsed(certificateID, issuanceDate, revocablePeriod);
        }
    }

    /**
     * @notice checkClaimableProof - Checks if a claim certification request valid
     * @dev A claim request is valid if the certificate is not revoked
     * @dev A claim request is valid if the requested claimed volume is less or equal to the total value owned by the claimer
     * @dev This function reverts if one the above requirements is not met
     * @param certificateID - ID of the certificate being checked
     * @param claimer - address of the claimer
     * @param claimedVolume - volume of the certificate being claimed
     * @param ownedBalance - balance of the certificate owned by the claimer
     */
    function checkClaimableProof(uint256 certificateID, address claimer, uint256 claimedVolume, uint256 ownedBalance) internal view {
        if (LibIssuer.isCertificateRevoked(certificateID)) {
            revert ProofRevoked(certificateID);
        }

        if (ownedBalance < claimedVolume) {
            revert InsufficientBalance(claimer, certificateID, claimedVolume);
        }
    }

    /**
     * @notice checkOwnedCertificates - Checks if a user owns any certificates
     * @dev A users owns some certificates if her/his list of owned tokens is not empty
     * @dev This function reverts if the number of certificates owned by the userAddress 0
     * @param userTokensListSize - number of certificates owned by the userAddress
     * @param userAddress - address of the user being checked
     */
    function checkOwnedCertificates(uint256 userTokensListSize, address userAddress) internal pure {
        if (userTokensListSize == 0) {
            revert NoProofsOwned(userAddress);
        }
    }

    /**
     * @notice checkProofValidity - Checks if a proof is valid
     * @dev The proof is the list of all hashes defining the path from a merkle tree's root to the specified leaf
     * @param rootHash - root hash of the proof
     * @param leaf - leaf of the proof
     * @param proof - the proof being verified
     */
    function checkProofValidity(bytes32 rootHash, bytes32 leaf, bytes32[] memory proof) internal pure {
        if (verifyProof(rootHash, leaf, proof) == false) {
            revert InvalidProof(rootHash, leaf, proof);
        }
    }

    /**
     * @notice verifyProof - Verifies that a proof is part of a Merkle tree
     * @dev The verification of a proof is made using Openzeppelin's Merkle trees verification (https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof)
     * @param rootHash - root hash of the of the merkle tree representing the data to certify
     * @param leaf - leaf of the merkle tree representing the data to certify
     * @param proof - the proof being verified
     * @return true if the proof is valid, false otherwise
     */
    function verifyProof(bytes32 rootHash, bytes32 leaf, bytes32[] memory proof) internal pure returns (bool) {
        return MerkleProof.verify(proof, rootHash, leaf);
    }
}
