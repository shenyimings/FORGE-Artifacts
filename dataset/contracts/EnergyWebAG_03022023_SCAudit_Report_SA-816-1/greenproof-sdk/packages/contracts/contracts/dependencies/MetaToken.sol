// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IMetaToken} from "../interfaces/IMetaToken.sol";
import {SolidStateERC1155} from "@solidstate/contracts/token/ERC1155/SolidStateERC1155.sol";

/**
 * @title MetaToken
 * @dev This contract is used to issue derived tokens from a parent token contract.
 * @author EnergyWeb Foundation
 * @notice This contract is used to issue derived tokens from a parent token contract.
 */

contract MetaToken is IMetaToken, SolidStateERC1155 {
    address private _admin;
    string public name;
    string public symbol;
    mapping(uint256 => uint256) public tokenRevocationDate;

    modifier onlyAdmin() {
        if (msg.sender != _admin) {
            revert NotAdmin(msg.sender);
        }
        _;
    }

    modifier preventZeroAddressReceiver(address receiver) {
        if (receiver == address(0)) {
            revert invalidZeroAddress();
        }
        _;
    }

    constructor(address admin, string memory _name, string memory _symbol) {
        _admin = admin;
        name = _name;
        symbol = _symbol;
    }

    /**
     * @notice issueMeToken - Issues a meta token
     * @dev This function can only be called by the contract admin
     * @dev This function reverts if the receiver address is the zero address
     * @param tokenID - ID of the meta token to be issued
     * @param amount - Amount of the meta token to be issued
     * @param receiver - Address of the receiver of the meta token
     * @param tokenUri - URI of the meta token
     */
    function issueMetaToken(
        uint256 tokenID,
        uint256 amount,
        address receiver,
        string memory tokenUri
    ) external onlyAdmin preventZeroAddressReceiver(receiver) {
        _safeMint(receiver, tokenID, amount, "");
        _setTokenURI(tokenID, tokenUri);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenIssued(tokenID, receiver, block.timestamp, amount);
    }

    /**
     * @notice revokeMeToken - Revokes a meta token
     * @dev This function can only be called by the admin
     * @dev This function reverts if the meta token is already revoked
     * @dev the timestamp of the revocation is stored in the tokenRevocationDate mapping
     * @param tokenID - ID of the meta token to be revoked
     */
    function revokeMetaToken(uint256 tokenID) external onlyAdmin {
        if (isMetaTokenRevoked(tokenID)) {
            revert RevokedToken(tokenID, tokenRevocationDate[tokenID]);
        }
        //solhint-disable-next-line not-rely-on-time
        tokenRevocationDate[tokenID] = block.timestamp;
    }

    /**
     * @notice claimMetaToken - Claims a meta token
     * @dev This function can only be called by the admin
     * @dev This function reverts if the meta token is already retired
     * @param tokenID - ID of the meta token to be claimed
     * @param amount - amount of meta tokens to be claimed
     */
    function claimMetaToken(uint256 tokenID, uint256 amount) external {
        _claimMetaTokenFor(tokenID, amount, msg.sender);
    }

    /**
     * @notice claimMetaTokenFor - Claims a meta token on the behalf of the owner
     * @dev This function can only be called by an enrolled claimer
     * @dev This function reverts if the meta token is already retired
     * @param tokenID - ID of the meta token to be claimed
     * @param amount - amount of meta tokens to be claimed
     * @param owner - address of the owner of the meta token
     */
    function claimMetaTokenFor(uint256 tokenID, uint256 amount, address owner) external onlyAdmin {
        _claimMetaTokenFor(tokenID, amount, owner);
    }

    /**
     * @notice tokenSupply - Returns the total supply of a meta token
     * @param id - ID of the meta token
     * @return uint256 - The total supply of the meta token
     */
    function tokenSupply(uint256 id) external view returns (uint256) {
        return _totalSupply(id);
    }

    /**
     * @notice getBalanceOf - Returns the balance of a meta token for an account
     * @param account - Address of the account
     * @param id - ID of the meta token
     * @return uint256 - The balance of the meta token for the account
     */
    function getBalanceOf(address account, uint256 id) external view returns (uint256) {
        return balanceOf(account, id);
    }

    /**
     * @notice isMetaTokenRevoked - Returns true if the metaToken is revoked
     * @param tokenID - ID of the meta token
     * @return bool - True if the meta token is revoked
     */
    function isMetaTokenRevoked(uint256 tokenID) public view returns (bool) {
        return tokenRevocationDate[tokenID] != 0;
    }

    /**
     * _beforeTokenTransfer - internal hook override for revocation check before any token transfer
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        uint256 nbTokens = ids.length;
        for (uint256 i; i < nbTokens; i++) {
            uint256 currentToken = ids[i];
            if (isMetaTokenRevoked(currentToken)) {
                revert RevokedToken(currentToken, tokenRevocationDate[currentToken]);
            }
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _claimMetaTokenFor(uint256 tokenID, uint256 amount, address owner) private {
        if (balanceOf(owner, tokenID) < amount) {
            revert InsufficientBalance(owner, tokenID, amount);
        }

        _burn(owner, tokenID, amount);
        // solhint-disable-next-line not-rely-on-time
        emit MetaTokenClaimed(tokenID, msg.sender, block.timestamp, amount);
    }
}
