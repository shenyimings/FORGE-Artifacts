// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC721/ERC721.sol";

contract MockNft is ERC721 {
    uint256 latestId = 0;

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function test_mock() external pure {}

    function mint(address receiver) external returns (uint256) {
        latestId++;

        _mint(receiver, latestId);

        return latestId;
    }
}
