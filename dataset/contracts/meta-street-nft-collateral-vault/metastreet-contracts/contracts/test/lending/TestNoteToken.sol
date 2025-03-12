// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title Test Note Token
 */
contract TestNoteToken is ERC721, Ownable {
    /**************************************************************************/
    /* Constructor */
    /**************************************************************************/

    /**
     * @notice TestNoteToken constructor
     */
    constructor() ERC721("Test Promissory Note", "TPN") {}

    /**************************************************************************/
    /* Privileged API */
    /**************************************************************************/

    /**
     * @notice Mint note token to account
     * @param to Recipient account
     * @param tokenId Note token ID
     */
    function mint(address to, uint256 tokenId) external virtual onlyOwner {
        _safeMint(to, tokenId);
    }

    /**
     * @notice Burn note token
     * @param tokenId Note token ID
     */
    function burn(uint256 tokenId) external virtual onlyOwner {
        _burn(tokenId);
    }

    /**************************************************************************/
    /* Getters */
    /**************************************************************************/

    /**
     * @notice Check if note token ID exists
     * @param tokenId Note token ID
     * @return True note token ID exists, otherwise false
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }
}
