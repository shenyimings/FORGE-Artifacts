// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract MockTokenNFT is ERC721Burnable, Ownable {
    constructor(string memory name_, string memory symbol_) public ERC721(name_, symbol_) {}

    function safeMint(
        address recipient,
        uint256 tokenID,
        bytes memory data
    ) external onlyOwner {
        _safeMint(recipient, tokenID, data);
    }
}