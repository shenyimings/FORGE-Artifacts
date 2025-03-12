// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SimpleERC1155 is ERC1155, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter nextTokenId;

    constructor() ERC1155("https://game.example/api/item/") {
        nextTokenId.increment();
    }

    function mintTo(address recipient, uint256 amount) external onlyOwner {
        uint256 tokenId = nextTokenId.current();
        _mint(recipient, tokenId, amount, "");
        nextTokenId.increment();
    }
}
