// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC721} from "../../../token/ERC721/ERC721.sol";
import {BaseMetadataURI} from "../../../metadata/BaseMetadataURI.sol";
import {MinterRole} from "@animoca/ethereum-contracts-core-1.1.1/contracts/access/MinterRole.sol";

contract ERC721Mock is ERC721, BaseMetadataURI, MinterRole {
    constructor() ERC721("ERC721Mock", "E721") MinterRole(msg.sender) {}

    /// @dev See {IERC721Metadata-tokenURI(uint256)}.
    function tokenURI(uint256 tokenId) external view virtual override returns (string memory) {
        require(address(uint160(_owners[tokenId])) != address(0), "ERC721: non-existing NFT");
        return _uri(tokenId);
    }

    /**
     * Unsafely mints a Non-Fungible Token.
     * @dev See {IERC721Mintable-mint(address,uint256)}.
     */
    function mint(address to, uint256 tokenId) external virtual {
        _requireMinter(_msgSender());
        _mint(to, tokenId, "", false);
    }

    /**
     * Unsafely mints a batch of Non-Fungible Token.
     * @dev See {IERC721Mintable-batchMint(address,uint256[])}.
     */
    function batchMint(address to, uint256[] calldata tokenIds) external virtual {
        _requireMinter(_msgSender());
        _batchMint(to, tokenIds);
    }

    /**
     * Safely mints a Non-Fungible Token.
     * @dev See {IERC721Mintable-safeMint(address,uint256,bytes)}.
     */
    function safeMint(
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external virtual {
        _requireMinter(_msgSender());
        _mint(to, tokenId, data, true);
    }
}
