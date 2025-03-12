// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

interface INFT {
  function init(
    address registry_,
    bytes32 domain_,
    string memory name_,
    string memory symbol_,
    string memory uri_
  ) external returns (bool);

  function safeTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external returns (bool);

  function batchMint(address to, uint256[] memory tokenIds) external returns (bool);

  function batchBurn(address to, uint256[] memory tokenIds) external returns (bool);

  function ownerOf(uint256 tokenId) external view returns (address);

  function mint(address to, uint256 tokenId) external returns (bool);

  function burn(uint256 tokenId) external returns (bool);

  function changeBaseURI(string memory uri_) external returns (bool);
}
