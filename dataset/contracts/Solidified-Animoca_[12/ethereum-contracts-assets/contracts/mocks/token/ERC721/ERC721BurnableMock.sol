// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {ERC721, ERC721Burnable} from "../../../token/ERC721/ERC721Burnable.sol";
import {IERC721Mintable} from "../../../token/ERC721/IERC721Mintable.sol";
import {BaseMetadataURI} from "../../../metadata/BaseMetadataURI.sol";
import {MinterRole} from "@animoca/ethereum-contracts-core-1.1.1/contracts/access/MinterRole.sol";

contract ERC721BurnableMock is ERC721Burnable, IERC721Mintable, BaseMetadataURI, MinterRole {
    constructor() ERC721("ERC721BurnableMock", "E721B") MinterRole(msg.sender) {}

    /// @dev See {IERC721Metadata-tokenURI(uint256)}.
    function tokenURI(uint256 nftId) external view virtual override returns (string memory) {
        require(address(uint160(_owners[nftId])) != address(0), "ERC721: non-existing NFT");
        return _uri(nftId);
    }

    //================================== ERC721Mintable =======================================/

    /**
     * Unsafely mints a Non-Fungible Token.
     * @dev See {IERC721Mintable-batchMint(address,uint256)}.
     */
    function mint(address to, uint256 nftId) public virtual override {
        _requireMinter(_msgSender());
        _mint(to, nftId, "", false);
    }

    /**
     * Unsafely mints a batch of Non-Fungible Tokens.
     * @dev See {IERC721Mintable-batchMint(address,uint256[])}.
     */
    function batchMint(address to, uint256[] memory nftIds) public virtual override {
        _requireMinter(_msgSender());
        _batchMint(to, nftIds);
    }

    /**
     * Safely mints a Non-Fungible Token.
     * @dev See {IERC721Mintable-safeMint(address,uint256,bytes)}.
     */
    function safeMint(
        address to,
        uint256 nftId,
        bytes memory data
    ) public virtual override {
        _requireMinter(_msgSender());
        _mint(to, nftId, data, true);
    }
}
