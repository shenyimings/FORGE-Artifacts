// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import './DuelistKingItem.sol';
import '../interfaces/IRNGConsumer.sol';
import '../libraries/RegistryUser.sol';
import '../libraries/Bytes.sol';
import '../interfaces/ITheDivine.sol';
import '../interfaces/INFT.sol';

/**
 * Card distributor
 * Name: Distributor
 * Domain: Duelist King
 */
contract DuelistKingDistributor is RegistryUser, IRNGConsumer {
  // Using Bytes for bytes
  using Bytes for bytes;

  // Using Duelist King Item for uint256
  using DuelistKingItem for uint256;

  // Item's serial
  uint256 private _itemSerial;

  // Card's serial
  uint256 private _cardSerial;

  // Default capped is 1,000,000 boxes
  uint256 private _capped = 1000000;

  // The Divine
  ITheDivine private immutable _theDivine;

  // Maping genesis
  mapping(uint256 => uint256) private _genesisEdition;

  // Map minted boxes
  mapping(uint256 => uint256) private _mintedBoxes;

  // Entropy data
  uint256 private _entropy;

  // New genesis card
  event NewGenesisCard(address indexed owner, uint256 indexed carId, uint256 indexed nftTokenId);

  // Set minted boxes
  event SetRemainingBoxes(uint256 indexed phaseId, uint256 indexed remainingBoxes);

  // Upgrade successful
  event CardUpgradeSuccessful(address owner, uint256 oldCardId, uint256 newCardId);

  // Upgrade failed
  event CardUpgradeFailed(address owner, uint256 oldCardId);

  constructor(
    address registry_,
    bytes32 domain_,
    address divine
  ) {
    _theDivine = ITheDivine(divine);
    _registryUserInit(registry_, domain_);
  }

  // Adding entropy to the pool
  function compute(bytes memory data) external override onlyAllowCrossDomain('Infrastructure', 'RNG') returns (bool) {
    require(data.length == 32, 'Distributor: Data must be 32 in length');
    // We combine random value with The Divine's result to prevent manipulation
    // https://github.com/chiro-hiro/thedivine
    _entropy ^= uint256(data.readUint256(0)) ^ _theDivine.rand();
    return true;
  }

  /*******************************************************
   * Public section
   ********************************************************/

  // Only owner able to open and claim cards
  function openBoxes(bytes memory nftIds) external {
    INFT nftItem = INFT(_registry.getAddress(_domain, 'NFT Item'));
    address owner = msg.sender;
    require(nftIds.length > 0 && nftIds.length % 32 == 0, 'Distributor: Invalid length of NFT IDs');
    uint256[] memory boxNftIds = new uint256[](nftIds.length / 32);
    for (uint256 i = 0; i < nftIds.length; i += 32) {
      uint256 nftId = nftIds.readUint256(i);
      boxNftIds[i / 32] = nftId;
      require(
        nftItem.ownerOf(nftId) == owner && _claimCardsInBox(owner, nftId),
        'Distributor: Unable to burn old box and issue cards'
      );
    }
    require(nftItem.batchBurn(owner, boxNftIds), 'Distributor: Unable to burn opened boxes');
  }

  /*******************************************************
   * Operator section
   ********************************************************/

  // Set remaining boxes
  function setRemainingBoxes(uint256 phaseId, uint256 numberOfBoxes)
    external
    onlyAllowSameDomain('Operator')
    returns (bool)
  {
    require(
      _mintedBoxes[phaseId] == 0 && numberOfBoxes > 0 && numberOfBoxes < _capped,
      "Distributor: Once this set you can't change"
    );
    _mintedBoxes[phaseId] = _capped - numberOfBoxes;
    emit SetRemainingBoxes(phaseId, numberOfBoxes);
    return true;
  }

  // Issue genesis edition for card creator
  function issueGenesisCard(address owner, uint256 id) external onlyAllowSameDomain('Operator') returns (uint256) {
    require(_genesisEdition[id] == 0, 'Distributor: Only one genesis edition will be distributed');
    _cardSerial += 1;
    uint256 cardId = uint256(0x0000000000000000ffff00000000000000000000000000000000000000000000)
      .setGeneration(id / 400)
      .setId(id)
      .setSerial(_cardSerial);
    require(INFT(_registry.getAddress(_domain, 'NFT Card')).mint(owner, cardId), 'Distributor: Unable to issue card');
    _genesisEdition[id] = cardId;
    emit NewGenesisCard(owner, id, cardId);
    return cardId;
  }

  /*******************************************************
   * Merchant section
   ********************************************************/

  // Mint boxes
  function mintBoxes(
    address owner,
    uint256 numberOfBoxes,
    uint256 phaseId
  ) external onlyAllowSameDomain('Merchant') returns (bool) {
    require(numberOfBoxes > 0 && numberOfBoxes <= 1000, 'Distributor: Invalid number of boxes');
    require(phaseId >= 1, 'Distributor: Invalid phase id');
    require(_mintedBoxes[phaseId] + numberOfBoxes <= _capped, 'Distributor: We run out of this box');
    uint256 itemSerial = _itemSerial;
    uint256 basedBox = uint256(0).setId(phaseId);
    uint256[] memory boxNftIds = new uint256[](numberOfBoxes);
    for (uint256 i = 0; i < numberOfBoxes; i += 1) {
      itemSerial += 1;
      // Overite item's serial
      boxNftIds[i] = basedBox.setSerial(itemSerial);
    }
    require(
      INFT(_registry.getAddress(_domain, 'NFT Item')).batchMint(owner, boxNftIds),
      'Distributor: Unable to issue item'
    );
    _itemSerial = itemSerial;
    _mintedBoxes[phaseId] += numberOfBoxes;
    return true;
  }

  /*******************************************************
   * Oracle section
   ********************************************************/

  // Upgrade card
  function upgradeCard(uint256 nftId, uint256 successTarget) external onlyAllowSameDomain('Oracle') returns (bool) {
    INFT nftCard = INFT(_registry.getAddress(_domain, 'NFT Card'));
    require(successTarget <= 1000000000, 'Distrubutor: Target must less than 1 billion');
    address owner = nftCard.ownerOf(nftId);
    require(owner != address(0), 'Distributor: Invalid token owner');
    uint256 rand = uint256(keccak256(abi.encodePacked(_entropy)));
    if (rand % 1000000000 <= successTarget) {
      _cardSerial += 1;
      uint256 newCardNftId = nftId.setType(nftId.getType() + 1).setSerial(_cardSerial);
      // Burn old card
      nftCard.burn(nftId);
      // Mint new card
      nftCard.mint(owner, newCardNftId);
      emit CardUpgradeSuccessful(owner, nftId, newCardNftId);
      return true;
    }
    emit CardUpgradeFailed(owner, nftId);
    return false;
  }

  /*******************************************************
   * Migrator section
   ********************************************************/

  function batchMigrate(
    address owner,
    bool isMint,
    bool isBox,
    bytes memory nftIdList
  ) external onlyAllowSameDomain('Migrator') {
    INFT nftContract = isBox
      ? INFT(_registry.getAddress(_domain, 'NFT Item'))
      : INFT(_registry.getAddress(_domain, 'NFT Card'));
    if (isMint) {
      require(nftContract.batchMint(owner, _bytesToArray(nftIdList)), 'Distributor: Unable to mint new NFT');
    } else {
      require(nftContract.batchBurn(owner, _bytesToArray(nftIdList)), 'Distributor: Unable to burn old NFT');
    }
  }

  /*******************************************************
   * Private section
   ********************************************************/

  // Open loot boxes
  function _claimCardsInBox(address owner, uint256 boxNftTokenId) private returns (bool) {
    INFT nftCard = INFT(_registry.getAddress(_domain, 'NFT Card'));
    // Card nft ids
    uint256[] memory cardNftIds = new uint256[](5);
    // Read entropy from openned card
    uint256 rand = uint256(keccak256(abi.encodePacked(_entropy)));
    // Box Id is equal to phase of card
    uint256 boxId = boxNftTokenId.getId();
    // Start point
    uint256 startPoint = boxId * 20 - 20;
    // 20 cards = 1 phase
    // 20 phases = 1 gen
    uint256 generation = startPoint / 400;
    // Serial of card
    uint256 serial = _cardSerial;
    for (uint256 i = 0; i < 5; ) {
      // Repeat hash on its selft
      rand = uint256(keccak256(abi.encodePacked(rand)));
      for (uint256 j = 0; j < 256 && i < 5; j += 32) {
        uint256 luckyNumber = (rand >> j) & 0xffffffff;
        // Draw card by lucky number
        uint256 card = _caculateCard(startPoint, luckyNumber);
        if (card > 0) {
          serial += 1;
          cardNftIds[i] = card.setGeneration(generation).setSerial(serial);
          i += 1;
        }
      }
    }
    require(nftCard.batchMint(owner, cardNftIds), 'Distributor: Can not mint NFT card');
    // Update card's serial
    _cardSerial = serial;
    // Update old random with new one
    _entropy = rand;
    return true;
  }

  // Calcualte card
  function _caculateCard(uint256 startPoint, uint256 luckyNumber) private view returns (uint256) {
    // Draw value from luckey number
    uint256 luckyDraw = luckyNumber % (_capped * 5);
    // Card distribution
    uint256[6] memory distribution = [
      uint256(0x00000000000000000000000000000001000000000000000600000000000009c4),
      uint256(0x000000000000000000000000000000020000000100000005000009c400006b6c),
      uint256(0x00000000000000000000000000000003000000030000000400006b6c00043bfc),
      uint256(0x00000000000000000000000000000004000000060000000300043bfc000fadac),
      uint256(0x000000000000000000000000000000050000000a00000002000fadac0026910c),
      uint256(0x000000000000000000000000000000050000000f000000010026910c004c4b40)
    ];
    for (uint256 i = 0; i < distribution.length; i += 1) {
      uint256 t = distribution[i];
      uint256 rEnd = t & 0xffffffff;
      uint256 rStart = (t >> 32) & 0xffffffff;
      uint256 rareness = (t >> 64) & 0xffffffff;
      uint256 cardStart = (t >> 96) & 0xffffffff;
      uint256 cardFactor = (t >> 128) & 0xffffffff;
      if (luckyDraw >= rStart && luckyDraw <= rEnd) {
        // Return card Id
        return uint256(0).setRareness(rareness).setId(startPoint + cardStart + (luckyNumber % cardFactor));
      }
    }
    return 0;
  }

  // Transform bytes string to uint256[]
  function _bytesToArray(bytes memory data) internal pure returns (uint256[] memory result) {
    require(data.length > 0 && data.length % 32 == 0, 'Distributor: Invalid length of data id');
    result = new uint256[](data.length / 32);
    for (uint256 i = 0; i < data.length; i += 32) {
      result[i / 32] = data.readUint256(i);
    }
  }

  /*******************************************************
   * View section
   ********************************************************/

  // Get remaining box of a phase
  function getRemainingBox(uint256 phaseId) external view returns (uint256) {
    return _capped - _mintedBoxes[phaseId];
  }

  // Get genesis token id of given card ID
  function getGenesisEdition(uint256 cardId) external view returns (uint256) {
    return _genesisEdition[cardId];
  }
}
