// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '../libraries/RegistryUser.sol';

/**
 * Only allow Press to mint new token following domain
 * Distributor will work with NFT through Press'
 * Name: NFT
 * Domain: Infrastructure
 */
contract NFT is RegistryUser, ERC721 {
  uint256 private _supply;

  string private _uri;

  constructor(
    address registry_,
    bytes32 domain_,
    string memory name_,
    string memory symbol_,
    string memory uri_
  ) ERC721(name_, symbol_) {
    _uri = uri_;
    _registryUserInit(registry_, domain_);
  }

  /*******************************************************
   * Distributor section
   ********************************************************/

  // Only distributor able to mint new item
  function mint(address to, uint256 tokenId) external onlyAllowSameDomain('Distributor') returns (bool) {
    _supply += 1;
    _mint(to, tokenId);
    return _exists(tokenId);
  }

  function batchMint(address to, uint256[] memory tokenIds) external onlyAllowSameDomain('Distributor') returns (bool) {
    uint256 beforeBalance = balanceOf(to);
    for (uint256 i = 0; i < tokenIds.length; i += 1) {
      _mint(to, tokenIds[i]);
    }
    uint256 afterBalance = balanceOf(to);
    _supply += tokenIds.length;
    require(afterBalance - beforeBalance == tokenIds.length, 'NFT: Minted amount does not correct');
    return true;
  }

  // Only distributor able to mint new item
  function burn(uint256 tokenId) external onlyAllowSameDomain('Distributor') returns (bool) {
    require(_supply > 0, 'NFT: Underflow detected');
    _supply -= 1;
    _burn(tokenId);
    return !_exists(tokenId);
  }

  function batchBurn(address to, uint256[] memory tokenIds) external onlyAllowSameDomain('Distributor') returns (bool) {
    require(_supply >= tokenIds.length, 'NFT: Underflow detected');
    uint256 beforeBalance = balanceOf(to);
    for (uint256 i = 0; i < tokenIds.length; i += 1) {
      _burn(tokenIds[i]);
    }
    uint256 afterBalance = balanceOf(to);
    _supply -= tokenIds.length;
    require(beforeBalance - afterBalance == tokenIds.length, 'NFT: Burnt amount does not correct');
    return true;
  }

  // Get base URI
  function _baseURI() internal view override returns (string memory) {
    return _uri;
  }

  // Change the base URI
  function changeBaseURI(string memory uri_) public onlyAllowSameDomain('Operator') returns (bool) {
    _uri = uri_;
    return true;
  }

  /*******************************************************
   * Swap cross domain section
   ********************************************************/

  // Allow swap to perform transfer
  function safeTransfer(
    address from,
    address to,
    uint256 tokenId
  ) external onlyAllowCrossDomain('Infrastructure', 'Swap') returns (bool) {
    _transfer(from, to, tokenId);
    return true;
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get total supply
  function totalSupply() external view returns (uint256) {
    return _supply;
  }
}
