// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { ERC721 } from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import { ERC20 } from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import { ERC721Enumerable } from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import { ERC721Burnable } from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { Base64 } from '@openzeppelin/contracts/utils/Base64.sol';
import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { PublicOrder } from './OrderStructs.sol';
import { OrderSignatureVerifierLib } from './libraries/OrderSignatureVerifierLib.sol';

/**
 * @title FundSwapOrderManager
 * @notice Manages the creation and storage of public orders which are represented as ERC721 tokens.
 */
contract FundSwapOrderManager is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
  error FundSwapOrderManager_OrderNotFound(bytes32 tokenHash);
  error FundSwapOrderManager__OrderAlreadyExists(bytes32 tokenHash);

  uint256 public tokenIdCounter;

  /// @dev tokenHash => order data
  mapping(bytes32 => PublicOrder) public orders;
  /// @dev tokenId => tokenHash
  mapping(uint256 => bytes32) public tokenIdToOrderHash;
  /// @dev tokenHash => tokenId
  mapping(bytes32 => uint256) public orderHashTotokenId;

  constructor() ERC721('FundSwap order', 'FSO') Ownable(_msgSender()) {}

  /**
   * gets the order data for a given token hash
   * @param tokenHash the has of the token to get the order data for
   */
  function getOrder(bytes32 tokenHash) public view returns (PublicOrder memory) {
    return orders[tokenHash];
  }

  /**
   * gets the order data for a given token ID
   * @param tokenId the has of the token to get the order data for
   */
  function getOrderById(uint256 tokenId) public view returns (PublicOrder memory) {
    return orders[tokenIdToOrderHash[tokenId]];
  }

  /**
   * gets the owner of an order with a given token hash
   * @param tokenHash the has of the token to get the order data for
   */
  function ownerOfByHash(bytes32 tokenHash) public view returns (address) {
    return ownerOf(orderHashTotokenId[tokenHash]);
  }

  /**
   * Creates a new public order and mints an ERC721 token representing it
   * @param to the address to mint the token to
   * @param order the order data
   * @return tokenId minted token number
   */
  function safeMint(
    address to,
    PublicOrder calldata order
  ) public onlyOwner returns (uint256 tokenId) {
    tokenId = tokenIdCounter++;
    bytes32 tokenHash = OrderSignatureVerifierLib.hashPublicOrder(order);
    if (_doesOrderExists(tokenHash)) {
      revert FundSwapOrderManager__OrderAlreadyExists(tokenHash);
    }
    orders[tokenHash] = order;
    tokenIdToOrderHash[tokenId] = tokenHash;
    orderHashTotokenId[tokenHash] = tokenId;
    _safeMint(to, tokenId);
  }

  /**
   * Burns an ERC721 token representing a public order and deletes the order data
   * @param tokenHash the id of the token to burn
   */
  function burn(bytes32 tokenHash) public onlyOwner {
    delete orders[tokenHash];
    uint256 tokenId = orderHashTotokenId[tokenHash];
    tokenIdToOrderHash[tokenId] = bytes32(0);
    orderHashTotokenId[tokenHash] = 0;
    super._burn(tokenId);
  }

  /**
   * Updates the order data for a public order. It is used to update orders in case when anohter user issued a
   * market order that partially filled the given public order.
   * @param tokenHash the id of the token to update
   * @param order the new order data
   */
  function updateOrder(bytes32 tokenHash, PublicOrder memory order) public onlyOwner {
    if (!_doesOrderExists(tokenHash)) {
      revert FundSwapOrderManager_OrderNotFound(tokenHash);
    }
    orders[tokenHash] = order;
  }

  /**
   * Returns the JSON representation of the public order data for a given token id.
   * @param tokenId the id of the token to get the order data for
   */
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    super._requireOwned(tokenId);

    PublicOrder memory order = orders[tokenIdToOrderHash[tokenId]];

    string memory json = Base64.encode(
      bytes(
        string(
          abi.encodePacked(
            '{"name": "',
            Strings.toString(order.makerSellTokenAmount),
            ' ',
            ERC20(order.makerSellToken).symbol(),
            ' => ',
            Strings.toString(order.makerBuyTokenAmount),
            ' ',
            ERC20(order.makerBuyToken).symbol(),
            '",',
            '"attributes": [',
            '{"trait_type": "Deadline", "value": "',
            Strings.toString(order.deadline),
            '"}',
            ']'
            '}'
          )
        )
      )
    );
    return string(abi.encodePacked('data:application/json;base64,', json));
  }

  function _doesOrderExists(bytes32 tokenHash) private view returns (bool) {
    return
      orders[tokenHash].makerBuyToken != address(0) &&
      orders[tokenHash].makerSellToken != address(0);
  }

  // following functions are overrides required by Solidity.

  function _update(
    address to,
    uint256 tokenId,
    address auth
  ) internal virtual override(ERC721, ERC721Enumerable) returns (address) {
    return super._update(to, tokenId, auth);
  }

  function _increaseBalance(
    address account,
    uint128 value
  ) internal virtual override(ERC721, ERC721Enumerable) {
    super._increaseBalance(account, value);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
