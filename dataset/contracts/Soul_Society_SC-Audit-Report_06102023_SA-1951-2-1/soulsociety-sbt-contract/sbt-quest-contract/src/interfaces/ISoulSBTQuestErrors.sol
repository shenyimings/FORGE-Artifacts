// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @dev Standard SoulSBTQuest.sol Errors
 * Interface of the ERC6093 custom errors for ERC721 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
 */

interface ISoulSBTQuestErrors {

    /*
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * @Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error SoulSBTQuestInvalidOwner(address to);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error SoulSBTQuestNonexistentToken(uint256 tokenId);

    
    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error SoulSBTQuestIncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates an error related to the ownership over a particular token.
     * @param owner Address of the current owner of a token.
     * @param to Address whose SBT token are being used.
     */
    error SoulSBTQuestNotOwner(address owner, address to);

    /**
     * @dev Indicates an error related to the ownership over a particular token.
     * @param owner Address of the current owner of a token.
     * @param tokenId tokenId Identifier number of a token
     */
    
    error SoulSBTQuestPermissionDenied(address owner, uint256 tokenId);

    /*
     * @dev Indicates a failure with the tokenId. Used in transfers.
     * @param tokedId to check
     */
    error SoulSBTQuestExistToken(uint256 tokenId);


    /*
     * @dev Indicates a failure with the adddress. 
     * @param address to check
     */   
    error SoulSBTQuestNonExist(address sender);


    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error SoulSBTQuestInvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error SoulSBTQuestInvalidReceiver(address receiver);


    /**
     * @dev Indicates protected status. Used in token.
     * @param owner Address.
     */
    error SoulSBTQuestProtectedOwner(address owner);


    error SoulSBTQuestNotSupported(string message);

}
