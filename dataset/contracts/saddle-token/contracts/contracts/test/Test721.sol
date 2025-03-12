// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Test721 is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("Test", "Symbol") {}

    function mint(uint256 tokenId) public {
        _mint(msg.sender, tokenId);
        totalSupply += 1;
    }
}
