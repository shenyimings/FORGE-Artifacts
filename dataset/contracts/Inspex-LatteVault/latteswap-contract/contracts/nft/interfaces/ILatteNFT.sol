// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721EnumerableUpgradeable.sol";

interface ILatteNFT is IERC721Upgradeable, IERC721MetadataUpgradeable, IERC721EnumerableUpgradeable {
  // getter

  function latteNames(uint256 tokenId) external view returns (string calldata);

  function categoryInfo(uint256 tokenId)
    external
    view
    returns (
      string calldata,
      string calldata,
      uint256
    );

  function latteNFTToCategory(uint256 tokenId) external view returns (uint256);

  function categoryToLatteNFTList(uint256 categoryId) external view returns (uint256[] memory);

  function currentTokenId() external view returns (uint256);

  function currentCategoryId() external view returns (uint256);

  function categoryURI(uint256 categoryId) external view returns (string memory);

  function getLatteNameOfTokenId(uint256 tokenId) external view returns (string memory);

  // setter
  function mint(
    address _to,
    uint256 _categoryId,
    string calldata _tokenURI
  ) external returns (uint256);

  function mintBatch(
    address _to,
    uint256 _categoryId,
    string calldata _tokenURI,
    uint256 _size
  ) external returns (uint256[] memory);
}
