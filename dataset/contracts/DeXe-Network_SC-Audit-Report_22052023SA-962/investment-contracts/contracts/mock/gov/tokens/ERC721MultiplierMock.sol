// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../gov/ERC721/multipliers/ERC721Multiplier.sol";

contract ERC721MultiplierMock is ERC721Multiplier {
    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
