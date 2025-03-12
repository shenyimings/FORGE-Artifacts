// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import {LibIssuer} from "../libraries/LibIssuer.sol";
import {LibVoting} from "../libraries/LibVoting.sol";
import {IProofIssuer} from "../interfaces/IProofIssuer.sol";
import {LibProofManager} from "../libraries/LibProofManager.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";
import {IERC1155} from "@solidstate/contracts/interfaces/IERC1155.sol";
import {ERC1155Base} from "@solidstate/contracts/token/ERC1155/base/ERC1155Base.sol";
import {SolidStateERC1155} from "@solidstate/contracts/token/ERC1155/SolidStateERC1155.sol";

/**
 * @title `IssuerFacet` - The issuance component of the GreenProof core module.
 * @author Energyweb Foundation
 * @notice This facet handles certificates Issuance as Green proofs. Certificates consists of ERC-1155 tokens anchored to merkleRoot hashes of data.
 * @dev This contract is a facet of the EW-GreenProof-Core Diamond, a gas optimized implementation of EIP-2535 Diamond proxy standard : https://eips.ethereum.org/EIPS/eip-2535
 */
contract IssuerFacet is SolidStateERC1155, IProofIssuer {
    /**
     * @notice modifier that restricts the execution of functions only to users enrolled as Issuers
     * @dev this modifer reverts the transaction if the msg.sender is not an enrolled issuer
     */
    modifier onlyIssuer() {
        LibClaimManager.checkEnrolledIssuer(msg.sender);
        _;
    }

    modifier onlyApprover() {
        LibClaimManager.checkEnrolledApprover(msg.sender);
        _;
    }

    /**
     * @notice `requestProofIssuance` - An authorized issuer requests proof issuance after a consensus is reached.
     * This runs the automatic data verification and the certificate minting process.
     * @param issuanceRequest - An IssuanceRequest struct containing the data needed to issue a certificate.
     */
    function requestProofIssuance(IssuanceRequest memory issuanceRequest) external onlyIssuer {
        _issueCertificate(
            issuanceRequest.voteID,
            issuanceRequest.generator,
            issuanceRequest.dataHash,
            issuanceRequest.dataProof,
            issuanceRequest.volume,
            issuanceRequest.amountProof,
            issuanceRequest.tokenUri
        );
    }

    /**
     * @notice `requestBatchIssuance` - An authorized issuer requests issuance of a bacth of certificates.
     * @param issuanceRequestsList - An array of IssuanceRequest struct containing the data needed to issue a certificate.
     * @dev This function is used to issue a batch of certificates after a consensus is reached.
     * @dev The MerkleProof verification uses the `merkleProof` library provided by openzeppelin/contracts -> https://docs.openzeppelin.com/contracts/3.x/api/cryptography#MerkleProof.
     * @dev The generator address can not be the zero address
     */
    function requestBatchIssuance(IssuanceRequest[] memory issuanceRequestsList) external onlyIssuer {
        uint256 listSize = issuanceRequestsList.length;
        LibIssuer.checkBatchIssuanceSize(listSize);
        for (uint256 i; i < listSize; i++) {
            _issueCertificate(
                issuanceRequestsList[i].voteID,
                issuanceRequestsList[i].generator,
                issuanceRequestsList[i].dataHash,
                issuanceRequestsList[i].dataProof,
                issuanceRequestsList[i].volume,
                issuanceRequestsList[i].amountProof,
                issuanceRequestsList[i].tokenUri
            );
        }
    }

    /**
     * @notice `simpleBatchTransfer` - An authorized operator requests transfer of a bacth of certificates.
     * @param transferRequestsList - An array of TransferRequest struct containing the data needed to transfer one certificate for each request.
     */
    function simpleBatchTransfer(TransferRequest[] memory transferRequestsList) external {
        uint256 listSize = transferRequestsList.length;
        LibIssuer.checkBatchTransferSize(listSize);
        for (uint256 i; i < listSize; i++) {
            safeTransferFrom(
                transferRequestsList[i].sender,
                transferRequestsList[i].recipient,
                transferRequestsList[i].certificateID,
                transferRequestsList[i].amount,
                transferRequestsList[i].data
            );
        }
    }

    /**
     * @notice `multipleBatchTransfer` - An authorized operator requests transfer of multiple batches of certificates.
     * @param transferBatchRequests - An array of TransferBatchRequest struct containing the data needed to transfer multiple certificates for each request.
     */
    function multipleBatchTransfer(TransferBatchRequest[] memory transferBatchRequests) external {
        uint256 listSize = transferBatchRequests.length;
        LibIssuer.checkBatchTransferSize(listSize);
        for (uint256 i; i < listSize; i++) {
            safeBatchTransferFrom(
                transferBatchRequests[i].sender,
                transferBatchRequests[i].recipient,
                transferBatchRequests[i].certificateIDs,
                transferBatchRequests[i].amounts,
                transferBatchRequests[i].data
            );
        }
    }

    /**
     * @notice `discloseData` - Publicly exposes specific a information of the certified data.
     * This information is a key-value pair composing the dataHash merkleTree
     * @param key - the key referencing the information inside the certified data set
     * @param value - the actual value of the information
     * @param dataProof - The proofs path to verify that key-value hashed data is part of dataHash merkleTree
     * @param dataHash - The merkleRoot hash of the certified data set.
     */
    function discloseData(string memory key, string memory value, bytes32[] memory dataProof, bytes32 dataHash) external override onlyIssuer {
        bytes32 leaf = keccak256(abi.encodePacked(key, value));

        LibIssuer.checkNotDisclosed(dataHash, key);
        LibProofManager.checkProofValidity(dataHash, leaf, dataProof);
        LibIssuer.discloseData(dataHash, key, value);
    }

    /**
     * @notice approveOperator -  Grants approval to an operator to transfer certificates of a specific certificate owner
     * @param operator The address of the operator being approved
     * @param certificateOwner The address of the certificate owner for whom the operator is being approved
     * @dev If the operator is already approved, the function will revert.
     * @dev If the caller of this function does not have the `approver` role, the function will revert.
     * @dev `msg.sender` cannot be the same as `operator`
     */
    function approveOperator(address operator, address certificateOwner) external onlyApprover {
        LibIssuer.preventAlreadyApproved(operator, certificateOwner);
        LibIssuer.setApprovalFor(certificateOwner, operator, true);
        emit OperatorApproved(operator, certificateOwner, msg.sender);
    }

    /**
     * @notice removeApprovedOperator -  revoke approval of an operator to transfer certificates of a specific certificate owner
     * @param operator The address of the operator being revoked
     * @param certificateOwner address of the user for whom the operator is being revoked transfer rights
     * @dev If transfer rights of operator has already been removed for this certificate owner, the function will revert.
     * @dev If the caller of this function does not have the `approver` role, the function will revert.
     */
    function removeApprovedOperator(address operator, address certificateOwner) external onlyApprover {
        LibIssuer.preventAlreadyRemovedOperator(operator, certificateOwner);
        LibIssuer.setApprovalFor(certificateOwner, operator, false);
        emit OperatorRemoved(operator, certificateOwner, msg.sender);
    }

    /**
     * @notice `getCertificateOwners` - Get the listing of all the wallets which hold a share of a specific certificate
     * @param certificateID - the id of the minted certificate
     * @return certificateOwners - The List of all users / wallets holding a share of this `certificateID`.
     */
    function getCertificateOwners(uint256 certificateID) external view returns (address[] memory certificateOwners) {
        certificateOwners = _accountsByToken(certificateID);
    }

    /**
     * @notice name - Returns the name of the certificate token
     * @return name - The name of the certificate token
     */
    function name() external view returns (string memory) {
        return LibIssuer.getTokenName();
    }

    /**
     * @notice symbol - Returns the symbol of the certificate token
     * @return symbol - The symbol of the certificate token
     */
    function symbol() external view returns (string memory) {
        return LibIssuer.getTokenSymbol();
    }

    /**
     * @notice transfer certificate between given addresses, checking for ERC1155Receiver implementation if applicable
     * @param from owner of certificate
     * @param to receiver of certificate
     * @param id certificate ID
     * @param amount quantity of certificate to transfer
     * @param data data payload
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public override(ERC1155Base, IERC1155) {
        LibIssuer.checkApprovedSender(from, msg.sender);
        LibIssuer.checkAllowedTransfer(id, to);
        _safeTransfer(msg.sender, from, to, id, amount, data);
    }

    /**
     * @notice transfer batch of certificates between given addresses, checking for ERC1155Receiver implementation if applicable
     * @param from owner of certificates
     * @param to receiver of certificates
     * @param ids list of certificate IDs
     * @param amounts list of quantities of certificates to transfer
     * @param data data payload
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override(ERC1155Base, IERC1155) {
        LibIssuer.checkApprovedSender(from, msg.sender);
        uint256 numberOfIds = ids.length;
        for (uint256 i; i < numberOfIds; i++) {
            LibIssuer.checkAllowedTransfer(ids[i], to);
        }
        _safeTransferBatch(msg.sender, from, to, ids, amounts, data);
    }

    /**
     * @notice _issueCertificate - Internal function to mint a new certificate
     * @param voteID - The voteID of the certified data set
     * @param generator - The address of the generator of the certified data set
     * @param dataHash - The merkleRoot hash of the certified data set.
     * @param dataProof - The proofs path to verify that dataHash is part of the consensus merkleTree
     * @param volume - The volume of the certified data set
     * @param amountProof - The proofs path to verify that volume is part of the consensus merkleTree
     * @param tokenUri - The URI of the certificate metadata
     * @dev The function will revert if the generator address is the zero address
     */
    function _issueCertificate(
        bytes32 voteID,
        address generator,
        bytes32 dataHash,
        bytes32[] memory dataProof,
        uint256 volume,
        bytes32[] memory amountProof,
        string memory tokenUri
    ) private {
        LibIssuer.preventZeroAddressReceiver(generator);
        LibIssuer.preventAlreadyCertified(dataHash);
        LibVoting.checkVoteInConsensus(voteID, dataHash, dataProof);
        LibIssuer.checkVolumeValidity(volume, dataHash, amountProof);
        uint256 nextCertificateId = LibIssuer.incrementAndGetProofIndex();
        uint256 volumeInWei = volume * 1 ether;
        LibIssuer.registerProof(dataHash, generator, volumeInWei, nextCertificateId, voteID);

        _safeMint(generator, nextCertificateId, volumeInWei, "");
        _setTokenURI(nextCertificateId, tokenUri);
        emit ProofMinted(nextCertificateId, volumeInWei, generator);
    }
}
