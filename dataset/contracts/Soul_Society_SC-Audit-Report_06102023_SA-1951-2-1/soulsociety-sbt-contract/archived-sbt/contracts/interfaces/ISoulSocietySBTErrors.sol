// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @dev Standard SoulSocietySBT.sol Errors
 * Interface of the ERC6093 custom errors for ERC721 tokens
 * as defined in https://eips.ethereum.org/EIPS/eip-6093
 */

interface ISoulSocietySBTErrors {

    /*
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * @Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error SoulSocietySBTInvalidOwner(address to);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error SoulSocietySBTNonexistentToken(uint256 tokenId);

    
    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error SoulSocietySBTIncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates an error related to the ownership over a particular token.
     * @param owner Address of the current owner of a token.
     * @param to Address whose SBT token are being used.
     */
    error SoulSocietySBTNotOwner(address owner, address to);

    /**
     * @dev Indicates an error related to the ownership over a particular token.
     * @param owner Address of the current owner of a token.
     * @param tokenId tokenId Identifier number of a token
     */
    
    error SoulSocietySBTPermissionDenied(address owner, uint256 tokenId);

    /*
     * @dev Indicates a failure with the tokenId. Used in transfers.
     * @param tokedId to check
     */
    error SoulSocietySBTExistToken(uint256 tokenId);


    /*
     * @dev Indicates a failure with the adddress. 
     * @param address to check
     */   
    error SoulSocietySBTNonExist(address sender);


    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error SoulSocietySBTInvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error SoulSocietySBTInvalidReceiver(address receiver);


    /**
     * @dev Indicates protected status. Used in token.
     * @param owner Address.
     */
    error SoulSocietySBTProtectedOwner(address owner);


    error SoulSocietySBTNotSupported(string message);
//    /**
//     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
//     * @param operator Address that may be allowed to operate on tokens without being their owner.
//     * @param tokenId Identifier number of a token.
//     */
//    error ERC721InsufficientApproval(address operator, uint256 tokenId);
//
//    /**
//     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
//     * @param approver Address initiating an approval operation.
//     */
//    error ERC721InvalidApprover(address approver);
//
//    /**
//     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
//     * @param operator Address that may be allowed to operate on tokens without being their owner.
//     */
//    error ERC721InvalidOperator(address operator);
}
