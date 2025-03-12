// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "../nERC721/nERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @dev nERC721 token with pausable and storage feature
 */

contract nNFT is nERC721Enumerable, Pausable {
    using Strings for uint256;

    // base URI of the token, the default ipfs url
    string private baseURI;
    // Optional mapping for token URIs,can use when the token is mint
    mapping(uint256 => string) private _tokenURIs;

    mapping(uint256 => bool) private _isIpfsURIs;

    constructor(
        string memory baseURI_,
        string memory name_,
        string memory symbol_
    ) nERC721(name_, symbol_) {
        baseURI = string(abi.encodePacked(baseURI_, symbol_, "/"));
    }

    /* ========== EVENTS ========== */
    event OnChangeBaseURI(string baseURI);
    event OnSetTokenURI(uint256 tokenId, bool isIpfsURI, string tokenURI);

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /* ========== VIEW FUNCTIONS ========== */
    /**
     * override tokenURI(uint256), remove restrict for tokenId exist.
     * the token may not exist but need to have URI info.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_exists(tokenId) && _isIpfsURI(tokenId)) {
            return string(_tokenURIs[tokenId]);
        } else {
            return string(abi.encodePacked(baseURI, tokenId.toString()));
        }
    }

    function getbaseURI() public view virtual returns (string memory) {
        return _baseURI();
    }

    function _isIpfsURI(uint256 tokenId) internal view returns (bool) {
        return _isIpfsURIs[tokenId];
    }

    function setPause() external onlyManagers {
        _pause();
    }

    function unsetPause() external onlyManagers {
        _unpause();
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {OnSetTokenURI} event.
     */

    function setIpfsURI(
        uint256 tokenId,
        bool isIpfsURI,
        string memory _tokenURI
    ) external virtual onlyManagers {
        require(_exists(tokenId), "!exist");
        _tokenURIs[tokenId] = _tokenURI;
        _isIpfsURIs[tokenId] = isIpfsURI;
        emit OnSetTokenURI(tokenId, isIpfsURI, _tokenURI);
    }

    /* ==========  MUTATIVE FUNCTIONS ========== */
    /*
     * @dev only Admin can change baseURI of NFT
     *
     * Emits a {OnChangeBaseURI} event.
     */

    function changeBaseURI(string memory newBaseURI) external onlyManagers {
        string memory symbol_ = symbol();
        baseURI = string(abi.encodePacked(newBaseURI, symbol_, "/"));
        emit OnChangeBaseURI(baseURI);
    }

    /**
     * @dev See {ERC721-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        require(!paused(), "paused()");
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        if (_isIpfsURI(tokenId)) {
            delete _isIpfsURIs[tokenId];
        }
    }
}
