// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Mock is ERC1155 {
    constructor() ERC1155("https://example.com/{id}.json") {
        // Mint tokens to the specified address upon deployment
        _mint(0x6B3751c5b04Aa818EA90115AA06a4D9A36A16f02, 1, 100000, "");
    }

    // mint function mints tokens to the specified address (respecting the ERC1155 standard)
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external {
        _mint(account, id, amount, data);
    }
}
