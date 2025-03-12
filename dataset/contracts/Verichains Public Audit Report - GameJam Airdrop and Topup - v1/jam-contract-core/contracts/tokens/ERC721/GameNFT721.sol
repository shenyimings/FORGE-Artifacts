/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameNFT721 is ERC721Enumerable, ERC721Burnable, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public baseTokenURI;
    Counters.Counter private _currentId;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI_
    ) ERC721(name, symbol) {
        baseTokenURI = baseTokenURI_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            AccessControl.supportsInterface(interfaceId) ||
            ERC721Enumerable.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "GameNFT721: token does not exist");
        return
            string(
                abi.encodePacked(
                    baseTokenURI,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function setBaseTokenURI(string memory baseTokenURI_) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "GameNFT721: must have admin role to set"
        );
        baseTokenURI = baseTokenURI_;
    }

    function mint(address to) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "GameNFT721: must have minter role to mint"
        );
        _safeMint(to, _currentId.current());
        _currentId.increment();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }
}
