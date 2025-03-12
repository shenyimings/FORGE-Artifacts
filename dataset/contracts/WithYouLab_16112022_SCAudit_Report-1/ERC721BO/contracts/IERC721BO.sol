// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IERC721BO is IERC165, IERC721Enumerable, IERC721Metadata{

    error NonexistentToken();
    error InvalidAddress();
    error CallerIsNotOwnerNorApproved();
    error CallerIsNotOwnerNorApprovedForAll();
    error IndexOutOfRange();
    error TransferToNonERC721ReceiverImplementer();
    error ExceededMaxOfMint();
    error TokenAlreadyMinted();
    error TransferFromIncorrectOwner();
    error ApproveToCaller();
}
