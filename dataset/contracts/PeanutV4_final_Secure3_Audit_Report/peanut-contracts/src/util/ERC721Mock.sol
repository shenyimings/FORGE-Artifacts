// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor() ERC721("Name", "MOCK") {
        this;
    }

    // mint function mints tokens to the specified address
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
