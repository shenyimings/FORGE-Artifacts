//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import {LibIssuer} from "../libraries/LibIssuer.sol";
import {IMetaToken} from "../interfaces/IMetaToken.sol";
import {MetaToken} from "../dependencies/MetaToken.sol";
import {IERC1155} from "@solidstate/contracts/interfaces/IERC1155.sol";

library LibMetaToken {
    struct MetaTokenStorage {
        // A boolean flag indicating whether the MetaCertificate feature is enabled or not
        bool isMetaCertificateEnabled;
        // address of the deployed ERC1155 meta token contract
        address metaTokenAddress;
        // Mapping from parent certificate ID to the amount of meta tokens issued
        mapping(address => mapping(uint256 => uint256)) metaTokenIssued;
        // Mapping from token ID to account balances, to track how much of certificate ID a wallet has claimed
        mapping(uint256 => mapping(address => uint256)) claimedBalances;
    }

    /**
     * @dev Tracking the storage position of the issuerStorage
     */
    bytes32 private constant _META_TOKEN_STORAGE_POSITION = keccak256("ewc.greenproof.metaToken.diamond.storage");

    /**
     * @notice event emitted when meta tokens are issued
     * @param parentCertificateID - ID of the meta token to be issued
     * @param receiver - address of the receiver of the issued tokens
     * @param issuanceDate - date of the issuance
     * @param amount - amount of meta tokens to be issued
     */
    event MetaTokenIssued(uint256 indexed parentCertificateID, address indexed receiver, uint256 issuanceDate, uint256 amount);

    /**
     * @notice event emitted when meta tokens are revoked
     * @param tokenID - ID of the meta token to be revoked
     * @param revocationDate - date of the revocation
     */
    event MetaTokenRevoked(uint256 indexed tokenID, uint256 indexed revocationDate);
    /**
     * @notice NotAllowedIssuance - error raised when a user tries to issue more meta certificates than owned balance of parent certificate
     * @dev Error: Issuance of the meta-certificate is not allowed
     * @param certificateID ID of the parent certificate
     * @param receiver address of the receiver of the certificate
     * @param toIssueVolume volume of the certificate
     * @param availableVolume available volume of the parent certificate
     */
    error NotAllowedIssuance(uint256 certificateID, address receiver, uint256 toIssueVolume, uint256 availableVolume);

    /**
     * @notice issueMetaToken - Issues new token units of metaceritificate
     * @param parentCertificateID - ID of the parent certificate
     * @param amount - Amount of meta tokens to be issued
     * @param receiver - Address of the receiver of the issued tokens
     */
    function issueMetaToken(uint256 parentCertificateID, uint256 amount, address receiver, string memory tokenUri) internal {
        LibIssuer.preventZeroAddressReceiver(receiver); //verify that the receiver is not a zero address
        checkAllowedIssuance(receiver, parentCertificateID, amount); // verify that the receiver is allowed to issue this amount meta tokens
        address metaTokenAddress = getMetaTokenAddress();

        IMetaToken(metaTokenAddress).issueMetaToken(parentCertificateID, amount, receiver, tokenUri);
        getStorage().metaTokenIssued[receiver][parentCertificateID] += amount;
    }

    /**
     * @notice revokeMetaToken - Revokes a meta token
     * @param tokenID - ID of the meta token to be revoked
     */
    function revokeMetaToken(uint256 tokenID) internal {
        address metaTokenAddress = getMetaTokenAddress();
        IMetaToken(metaTokenAddress).revokeMetaToken(tokenID);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenRevoked(tokenID, block.timestamp);
    }

    /**
     * @notice claimMetaToken - Claims a meta token
     * @param tokenID - ID of the meta token to be claimed
     * @param amount - Amount of meta tokens to be claimed
     */
    function claimMetaTokenFor(uint256 tokenID, uint256 amount, address owner) internal {
        MetaToken(getMetaTokenAddress()).claimMetaTokenFor(tokenID, amount, owner);
    }

    /**
     * @notice registerClaimedMetaToken - Registers a claimed Meta Token
     * @param certificateID ID of the claimed certificate
     * @param owner address of the user claiming the certificate
     * @param claimedAmount amount of the certificate being claimed
     */
    function registerClaimedMetaToken(uint256 certificateID, address owner, uint256 claimedAmount) internal {
        getStorage().claimedBalances[certificateID][owner] += claimedAmount;
    }

    /**
     * @notice checkAllowedIssuance - checks if the receiver is allowed to issue this amount of meta tokens
     * @param receiver address of the receiver of the meta tokens
     * @param parentCertificateID ID of the parent certificate
     * @param toIssueVolume volume of the meta tokens to be issued
     * @dev Error: Issuance of the meta-certificate is not allowed
     * @dev reverts if the receiver is not allowed to issue this amount of meta tokens
     */
    function checkAllowedIssuance(address receiver, uint256 parentCertificateID, uint256 toIssueVolume) internal view {
        uint256 availableParentVolume = IERC1155(address(this)).balanceOf(receiver, parentCertificateID);
        uint256 alreadyIssuedVolume = getStorage().metaTokenIssued[receiver][parentCertificateID];
        uint256 allowedIssuanceVolume = availableParentVolume - alreadyIssuedVolume;
        bool isParentCertificateRevoked = LibIssuer.isCertificateRevoked(parentCertificateID);
        if (availableParentVolume == 0 || allowedIssuanceVolume < toIssueVolume || isParentCertificateRevoked) {
            revert NotAllowedIssuance(parentCertificateID, receiver, toIssueVolume, allowedIssuanceVolume);
        }
    }

    /**
     * @notice checkExistance - checks if a meta token exists
     * @param tokenID - ID of the meta token
     * @dev reverts if the meta token does not exist
     */
    function checkExistance(uint256 tokenID) internal view {
        if (totalSupply(tokenID) == 0) {
            revert IMetaToken.MetaTokenNotFound(tokenID);
        }
    }

    /**
     * @notice getMetaTokenAddress - Gets the address of the deployed ERC1155 meta token contract
     * @return metaTokenManager - The address of the deployed ERC1155 meta token contract
     */
    function getMetaTokenAddress() internal view returns (address) {
        return getStorage().metaTokenAddress;
    }

    /**
     * @notice totalSupply - Returns the total supply of a meta token
     * @param tokenID - ID of the meta token
     * @return uint256 - The total supply of the meta token
     */
    function totalSupply(uint256 tokenID) internal view returns (uint256) {
        return IMetaToken(getMetaTokenAddress()).tokenSupply(tokenID);
    }

    /**
     * @notice getBalanceOf - Returns the balance of a meta token
     * @param account - Address of the account
     * @param tokenID - ID of the meta token
     * @return uint256 - The balance of the meta token
     */
    function getBalanceOf(address account, uint256 tokenID) internal view returns (uint256) {
        return MetaToken(getMetaTokenAddress()).balanceOf(account, tokenID);
    }

    /**
     * @notice isMetaTokenRevoked - Checks if a meta token is revoked
     * @param tokenID - ID of the meta token
     * @return bool - True if the meta token is revoked
     */
    function isMetaTokenRevoked(uint256 tokenID) internal view returns (bool) {
        return IMetaToken(getMetaTokenAddress()).isMetaTokenRevoked(tokenID);
    }

    /**
     * @notice isEnabled - Checks if the MetaCertificate feature is enabled
     * @return bool - True if the MetaCertificate feature is enabled
     */
    function isEnabled() internal view returns (bool) {
        return getStorage().isMetaCertificateEnabled;
    }

    /**
     *@notice claimedBalanceOf  - returns the amount volume of certifcates ID claimed by a owner
     * @param user - The user for whom we check claimed balance for
     * @param certificateID - ID of the greenproof certificate
     */
    function claimedBalanceOf(address user, uint256 certificateID) internal view returns (uint256) {
        return getStorage().claimedBalances[certificateID][user];
    }

    /**
     * @notice getStorage - Get the storage slot for MetaTokenStorage struct
     * @return metaTokenStorage - The pointer to the MetaToken storage
     */
    function getStorage() internal pure returns (MetaTokenStorage storage metaTokenStorage) {
        bytes32 position = _META_TOKEN_STORAGE_POSITION;

        /* solhint-disable-next-line no-inline-assembly */
        assembly {
            metaTokenStorage.slot := position
        }
    }
}
