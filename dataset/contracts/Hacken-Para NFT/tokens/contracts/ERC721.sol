//SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PARANFT is ERC721Enumerable, Ownable {
  uint256 public immutable MAX_SUPPLY;
  uint256 public immutable RESERVE_SUPPLY;
  uint256 public immutable PRICE;
  uint256 private tokenCounter;
  bool public saleActive;

  string private URI = "";

  constructor(
    string memory _name,
    string memory _shortcode,
    uint256 _supply,
    uint256 _reserve,
    uint256 _price
  ) ERC721(_name, _shortcode) {
    MAX_SUPPLY = _supply;
    RESERVE_SUPPLY = _reserve;
    PRICE = _price;
  }

  function _baseURI() internal view override returns (string memory) {
    return URI;
  }

  function setURI(string memory _URI) external onlyOwner {
    URI = _URI;
  }

  function flipSale() external onlyOwner {
    saleActive = !saleActive;
  }

  function mint(address to, uint256 amount) external payable {
    require(saleActive, "Sale inactive");
    require(amount <= 10, "Exceeds 10");
    require(amount + tokenCounter <= MAX_SUPPLY - RESERVE_SUPPLY, "Supply limit");
    require(msg.value >= PRICE * amount, "Incorrect ETH");

    // Solidity optimization
    uint256 _tokenCounter = tokenCounter;
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _tokenCounter);
      _tokenCounter++;
    }
    tokenCounter = _tokenCounter;
  }

  function withdraw() external onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }

  function forge(address to, uint256 amount) external onlyOwner {
    require(amount + tokenCounter <= MAX_SUPPLY, "Supply limit!");

    // Solidity optimization
    uint256 _tokenCounter = tokenCounter;
    for (uint256 i = 0; i < amount; i++) {
      _safeMint(to, _tokenCounter);
      _tokenCounter++;
    }
    tokenCounter = _tokenCounter;
  }
}
