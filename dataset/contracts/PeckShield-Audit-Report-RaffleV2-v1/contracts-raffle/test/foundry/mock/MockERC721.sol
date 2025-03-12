// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721("MockERC721", "MockERC721") {
    uint256 public totalSupply;

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
        totalSupply += 1;
    }

    function batchMint(
        address to,
        uint256 fromTokenId,
        uint256 count
    ) public {
        for (uint256 i; i < count; i++) {
            _mint(to, fromTokenId + i);
        }
        totalSupply += count;
    }
}
