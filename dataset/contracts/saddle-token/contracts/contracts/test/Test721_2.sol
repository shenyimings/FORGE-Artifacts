// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Test721_2 is ERC721 {
    uint256 public totalSupply;

    constructor() ERC721("Test", "Symbol") {}

    function mint() public {
        _mint(msg.sender, totalSupply);
        totalSupply += 1;
    }
}
