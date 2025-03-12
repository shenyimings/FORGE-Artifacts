// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../gov/ERC721/powers/ERC721RawPower.sol";

contract ERC721RawPowerMock is ERC721RawPower {
    function mockInit() external {
        __AbstractERC721Power_init("", "", 0, address(0), 0, 0, 0);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
