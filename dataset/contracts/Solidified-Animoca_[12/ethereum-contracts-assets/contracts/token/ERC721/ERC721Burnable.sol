// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6 <0.8.0;

import {IERC721Burnable} from "./IERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";

/**
 * @title ERC721Burnable, a burnable ERC721.
 */
abstract contract ERC721Burnable is IERC721Burnable, ERC721 {
    //================================== ERC165 =======================================/

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC721Burnable).interfaceId || super.supportsInterface(interfaceId);
    }

    //============================== ERC721Burnable =======================================/

    /**
     * Burns an NFT (ERC721-compatible).
     * @dev See {IERC721Burnable-burnFrom(address,uint256)}.
     */
    function burnFrom(address from, uint256 tokenId) public virtual override {
        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        _burnNFT(from, tokenId, operatable, false);
        emit Transfer(from, address(0), tokenId);
    }

    /**
     * Burns a batch of token (ERC721-compatible).
     * @dev See {IERC721Burnable-batchBurnFrom(address,uint256[])}.
     */
    function batchBurnFrom(address from, uint256[] memory tokenIds) public virtual override {
        address sender = _msgSender();
        bool operatable = _isOperatable(from, sender);

        uint256 length = tokenIds.length;

        for (uint256 i; i != length; ++i) {
            uint256 tokenId = tokenIds[i];
            _burnNFT(from, tokenId, operatable, true);
            emit Transfer(from, address(0), tokenId);
        }

        if (length != 0) {
            _nftBalances[from] -= length;
        }
    }

    //============================== Internal Helper Functions =======================================/

    function _burnNFT(
        address from,
        uint256 id,
        bool operatable,
        bool isBatch
    ) internal virtual {
        uint256 owner = _owners[id];
        require(from == address(uint160(owner)), "ERC721: non-owned NFT");
        if (!operatable) {
            require((owner & _APPROVAL_BIT_TOKEN_OWNER_ != 0) && _msgSender() == _nftApprovals[id], "ERC721: non-approved sender");
        }
        _owners[id] = _BURNT_NFT_OWNER;

        if (!isBatch) {
            // cannot underflow as balance is verified through NFT ownership
            --_nftBalances[from];
        }
    }
}
