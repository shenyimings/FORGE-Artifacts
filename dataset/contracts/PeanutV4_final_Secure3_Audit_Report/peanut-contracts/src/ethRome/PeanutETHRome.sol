// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//////////////////////////////////////////////////////////////////////////////////////
// @title   Peanut Eth Rome 2023
// @notice  A celebratory NFT for ETH Rome 2023
//          more at: https://peanut.to and https://ethrome.org
//////////////////////////////////////////////////////////////////////////////////////
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⣀⣤⣶⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⢀⣴⣿⣿⡿⠿⣿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⢠⣾⠉⢹⣿⣇⣀⣿⣷⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⣠⣿⣷⣿⣿⣿⣿⣿⣿⢷⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠘⣿⠋⢹⣿⡇⠀⣿⣇⣀⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⣶⣿⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⣿⣿⣿⣿⣷⣄⣀⣀⣤⣤⣀⠀⠀
// ⠀⢀⠟⣿⠟⢻⣿⡟⠛⣿⡟⠉⣿⣿⠋⠙⡄⢹⠉⢻⣿⠛⢻⣿⡟⢻⣿⠛⠀⠀
// ⠀⢸⣀⣿⣀⣸⣿⣇⣀⣿⣧⣤⣿⣿⣤⣤⣧⠀⠀⢸⣿⣀⣸⣿⣇⣀⣿⣀⡇⠀
// ⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣦⠈⣿⣿⣿⣿⣿⣿⣿⡿⡇⠀
// ⠀⢸⠀⣿⠁⢹⣿⡇⠈⣿⡟⠈⣿⣿⠁⠈⣿⣿⠁⢂⠘⠁⢸⣿⡇⠘⣿⠁⡇⠀
// ⠀⠈⠀⠛⠀⠘⠿⠇⠀⠿⠃⠀⠈⠻⠀⠀⠿⠟⠀⠘⠆⠀⠸⠿⠃⠀⠛⠀⠁⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
//////////////////////////////////////////////////////////////////////////////////////

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PeanutETHRome is ERC721URIStorage {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;

    uint256 public constant MAX_SUPPLY = 250;
    uint256 public totalSupply = 0;

    string public baseURI = "ipfs://bafybeiac5mthfbr4kba347nbc2ls36exjzhywapb63ii3wg76qv2a3dvdu";

    constructor() ERC721("Hacker @ ETH Rome 2023", "ROME23") {}

    modifier underMaxSupply() {
        require(totalSupply < MAX_SUPPLY, "Total supply reached");
        _;
    }

    function mint(address _hacker) public underMaxSupply returns (uint256) {
        uint256 newId = _tokenIds.current();
        _mint(_hacker, newId);
        _tokenIds.increment();
        totalSupply++;
        return newId;
    }

    function batchMint(address _hacker, uint256 _numTokens) public returns (uint256[] memory) {
        require(totalSupply + _numTokens <= MAX_SUPPLY, "Exceeds max supply");

        uint256[] memory newIds = new uint256[](_numTokens);
        for (uint256 i = 0; i < _numTokens; i++) {
            newIds[i] = mint(_hacker);
        }
        return newIds;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        uint256 offsetTokenId = tokenId + 1;
        return string(abi.encodePacked(baseURI, "/", offsetTokenId.toString(), ".json"));
    }
}
