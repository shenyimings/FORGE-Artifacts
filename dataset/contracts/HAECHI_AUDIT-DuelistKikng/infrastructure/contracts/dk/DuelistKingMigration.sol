// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract DuelistKingMigration is Ownable {
  IERC721 immutable nftCard;
  IERC721 immutable nftBox;

  constructor(address nftCard_, address nftBox_) {
    nftCard = IERC721(nftCard_);
    nftBox = IERC721(nftBox_);
  }

  function migrateCard(uint256[] calldata tokenIds) external {
    for (uint256 i; i < tokenIds.length; i += 1) {
      nftCard.transferFrom(msg.sender, address(this), tokenIds[i]);
    }
  }

  function migrateBox(uint256[] calldata tokenIds) external {
    for (uint256 i; i < tokenIds.length; i += 1) {
      nftBox.transferFrom(msg.sender, address(this), tokenIds[i]);
    }
  }

  function approveAll(address migrator) external onlyOwner {
    nftCard.setApprovalForAll(migrator, true);
    nftBox.setApprovalForAll(migrator, true);
  }
}
