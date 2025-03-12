// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
  constructor(string memory _name, string memory _symbol) public ERC721(_name, _symbol) {}

  function mint(address _to, uint256 id) public {
    _mint(_to, id);
  }
}
