/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SuperfineNFT721Airdrop is ERC721, AccessControl {
    using Counters for Counters.Counter;

    string public baseTokenURI;
    Counters.Counter private _currentId;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name, symbol) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        baseTokenURI = baseURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, AccessControl) returns (bool) {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(
            _exists(tokenId),
            "SuperfineNFT721Airdrop: token does not exist"
        );
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
            "SuperfineNFT721Airdrop: must have admin role to set"
        );
        baseTokenURI = baseTokenURI_;
    }

    function mint(address to) external {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "SuperfineNFT721Airdrop: must have minter role to mint"
        );
        _safeMint(to, _currentId.current());
        _currentId.increment();
    }
}
