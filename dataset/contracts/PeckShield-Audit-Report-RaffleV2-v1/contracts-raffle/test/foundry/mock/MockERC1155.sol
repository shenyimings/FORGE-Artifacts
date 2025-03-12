// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("MockERC1155") {}

    function batchMint(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) public {
        require(tokenIds.length == amounts.length, "tokenIds and amounts length mismatch");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mint(to, tokenIds[i], amounts[i], "");
        }
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) public {
        _mint(to, tokenId, amount, "");
    }
}
