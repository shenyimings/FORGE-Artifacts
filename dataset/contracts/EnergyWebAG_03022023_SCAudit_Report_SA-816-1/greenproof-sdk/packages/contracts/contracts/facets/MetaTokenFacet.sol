// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import {LibIssuer} from "../libraries/LibIssuer.sol";
import {IMetaToken} from "../interfaces/IMetaToken.sol";
import {LibMetaToken} from "../libraries/LibMetaToken.sol";
import {LibClaimManager} from "../libraries/LibClaimManager.sol";

contract MetaTokenFacet is IMetaToken {
    modifier onlyWhenEnabled() {
        if (!LibMetaToken.isEnabled()) {
            revert MetaTokenIssuanceDisabled();
        }
        _;
    }

    /**
     * @notice issueMetaToken - Issues new token units of metaceritificate
     * @dev This function reverts when the metatoken feature is not enabled
     * @param parentCertificateID - ID of the parent certificate
     * @param volume - Amount of meta tokens to be issued
     * @param receiver - Address of the receiver of the issued tokens
     */
    function issueMetaToken(uint256 parentCertificateID, uint256 volume, address receiver, string memory tokenUri) external onlyWhenEnabled {
        LibClaimManager.checkEnrolledIssuer(msg.sender); //verify that the sender is an authorized issuer
        uint256 amount = volume * 1 ether;
        LibMetaToken.issueMetaToken(parentCertificateID, amount, receiver, tokenUri);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenIssued(parentCertificateID, receiver, block.timestamp, amount);
    }

    /**
     * @notice `revokeMetaToken` - Revokes a meta token
     * @param tokenID - ID of the meta token to be revoked
     * @dev This function can only be called by an authorized revoker
     */
    function revokeMetaToken(uint256 tokenID) external {
        LibClaimManager.checkEnrolledRevoker(msg.sender); //verify that the sender is an authorized revoker
        LibMetaToken.checkExistance(tokenID);
        LibMetaToken.revokeMetaToken(tokenID);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenRevoked(tokenID, block.timestamp);
    }

    /**
     * @notice `claimMetaToken` - Claims a meta token
     * @dev This function reverts when the metatoken feature is not enabled
     * @param certificateID - ID of the meta token to be claimed
     * @param amount - Amount of meta tokens to be claimed
     */
    function claimMetaToken(uint256 certificateID, uint256 amount) external onlyWhenEnabled {
        _claimMetaTokenFor(certificateID, amount, msg.sender);
    }

    /**
     * @notice claimMetaTokenFor - Claims a meta token on the behalf of the owner
     * @dev This function can only be called by an enrolled claimer
     * @dev This function reverts if the meta token is already retired
     * @dev This function reverts when the metatoken feature is not enabled
     * @param certificateID - ID of the meta certificate to be claimed
     * @param amount - amount of meta tokens to be claimed
     * @param owner - address of the owner of the meta token
     */
    function claimMetaTokenFor(uint256 certificateID, uint256 amount, address owner) external onlyWhenEnabled {
        LibClaimManager.checkEnrolledClaimer(msg.sender);
        _claimMetaTokenFor(certificateID, amount, owner);
    }

    /**
     * @notice `getTokenAddress` - Returns the address of the ERC1155 tokenn contract
     * @return address - The address of the ERC1155 token contract
     */
    function getMetaTokenAddress() external view returns (address) {
        return LibMetaToken.getMetaTokenAddress();
    }

    /**
     * @notice tokenSupply - Returns the total supply of a meta token
     * @param id - ID of the meta token
     * @return uint256 - The total supply of the meta token
     */
    function tokenSupply(uint256 id) external view returns (uint256) {
        return LibMetaToken.totalSupply(id);
    }

    /**
     * @notice getBalanceOf - Returns the balance of a meta token
     * @param account - Address of the account
     * @param id - ID of the meta token
     * @return uint256 - The balance of the meta token
     */
    function getBalanceOf(address account, uint256 id) external view returns (uint256) {
        return LibMetaToken.getBalanceOf(account, id);
    }

    /**
     *@notice balanceClaimed  - returns the amount volume of certifcates ID claimed by a owner
     * @param user - The user for whom we check claimed balance for
     * @param certificateID - ID of the greenproof certificate
     */
    function balanceClaimed(address user, uint256 certificateID) external view returns (uint256) {
        return LibMetaToken.claimedBalanceOf(user, certificateID);
    }

    /**
     * @notice isMetaTokenRevoked - Returns true if the metaToken is revoked
     * @param tokenID - ID of the meta token
     * @return bool - True if the meta token is revoked
     */
    function isMetaTokenRevoked(uint256 tokenID) external view returns (bool) {
        return LibMetaToken.isMetaTokenRevoked(tokenID);
    }

    /**
     * @notice claimMetaTokenFor - Claims a meta token on the behalf of the owner
     * @dev This function can only be called by an enrolled claimer
     * @dev This function reverts if the meta token is already retired
     * @param certificateID - ID of the meta certificate to be claimed
     * @param amount - amount of meta tokens to be claimed
     * @param owner - address of the owner of the meta token
     */
    function _claimMetaTokenFor(uint256 certificateID, uint256 amount, address owner) private {
        LibMetaToken.claimMetaTokenFor(certificateID, amount, owner);
        LibMetaToken.registerClaimedMetaToken(certificateID, owner, amount);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenClaimed(certificateID, msg.sender, block.timestamp, amount);
    }
}
