/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SuperfineNFT1155Airdrop is ERC1155, AccessControl {
    using Strings for uint256;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory uri_) ERC1155(uri_) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    super.uri(tokenId),
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function setBaseTokenURI(string memory baseTokenURI_) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "SuperfineNFT1155Airdrop: caller is not an admin"
        );

        _setURI(baseTokenURI_);
    }

    function mint(
        address to,
        uint256 id,
        uint256 quantity,
        bytes memory data
    ) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "SuperfineNFT1155Airdrop: must have minter role to mint"
        );
        _mint(to, id, quantity, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory quantities,
        bytes memory data
    ) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "SuperfineNFT1155Airdrop: must have minter role to mint"
        );
        _mintBatch(to, ids, quantities, data);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return
            ERC1155.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
