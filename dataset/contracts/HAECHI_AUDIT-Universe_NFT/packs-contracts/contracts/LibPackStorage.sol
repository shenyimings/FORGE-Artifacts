// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import 'base64-sol/base64.sol';

library LibPackStorage {
  using SafeMath for uint256;

  bytes32 constant STORAGE_POSITION = keccak256("com.universe.packs.storage");

  struct Fee {
    address payable recipient;
    uint256 value;
  }

  struct SingleCollectible {
    string title; // Collectible name
    string description; // Collectible description
    uint256 count; // Amount of editions per collectible
    string[] assets; // Each asset in array is a version
    uint256 totalVersionCount; // Total number of existing states
    uint256 currentVersion; // Current existing state
  }

  struct Metadata {
    string[] name; // Trait or attribute property field name
    string[] value; // Trait or attribute property value
    bool[] modifiable; // Can owner modify the value of field
    uint256 propertyCount; // Tracker of total attributes
  }

  struct Collection {
    bool initialized;

    string baseURI; // Token ID base URL

    mapping (uint256 => SingleCollectible) collectibles; // Unique assets
    mapping (uint256 => Metadata) metadata; // Trait & property attributes, indexes should be coupled with 'collectibles'
    mapping (uint256 => Metadata) secondaryMetadata; // Trait & property attributes, indexes should be coupled with 'collectibles'
    mapping (uint256 => Fee[]) secondaryFees;
    mapping (uint256 => string) licenseURI; // URL to external license or file
    mapping (address => bool) mintPassClaimed;
    mapping (uint256 => bool) mintPassClaims;

    uint256 collectibleCount; // Total unique assets count
    uint256 totalTokenCount; // Total NFT count to be minted
    uint256 tokenPrice;
    uint256 bulkBuyLimit;
    uint256 saleStartTime;
    bool editioned; // Display edition # in token name
    uint256 licenseVersion; // Tracker of latest license

    uint64[] shuffleIDs;

    ERC721 mintPassContract;
    bool mintPass;
    bool mintPassOnly;
    bool mintPassFree;
    bool mintPassBurn;
    bool mintPassOnePerWallet;
    uint256 mintPassDuration;
  }

  struct Storage {
    address relicsAddress;
    address payable daoAddress;
    bool daoInitialized;

    uint256 collectionCount;

    mapping (uint256 => Collection) collection;
  }

  function packStorage() internal pure returns (Storage storage ds) {
    bytes32 position = STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  event LogMintPack(
    address minter,
    uint256 tokenID
  );

  event LogCreateNewCollection(
    uint256 index
  );

  event LogAddCollectible(
    uint256 cID,
    string title
  );

  event LogUpdateMetadata(
    uint256 cID,
    uint256 collectibleId,
    uint256 propertyIndex,
    string value
  );

  event LogAddVersion(
    uint256 cID,
    uint256 collectibleId,
    string asset
  );

  event LogUpdateVersion(
    uint256 cID,
    uint256 collectibleId,
    uint256 versionNumber
  );

  event LogAddNewLicense(
    uint256 cID,
    string license
  );

  function random(uint256 cID) internal view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, packStorage().collection[cID].totalTokenCount)));
  }

  function randomTokenID(address relics, uint256 cID) external relicSafety(relics) returns (uint256, uint256) {
    Storage storage ds = packStorage();

    uint256 randomID = random(cID) % ds.collection[cID].shuffleIDs.length;
    uint256 tokenID = ds.collection[cID].shuffleIDs[randomID];

    emit LogMintPack(msg.sender, tokenID);

    return (randomID, tokenID);
  }

  modifier onlyDAO() {
    require(msg.sender == packStorage().daoAddress, "Wrong address");
    _;
  }

  modifier relicSafety(address relics) {
    Storage storage ds = packStorage();
    require(relics == ds.relicsAddress);
    _;
  }

  /**
   * Map token order w/ URI upon mints
   * Sample token ID (edition #77) with collection of 12 different assets: 1200077
   */
  function createTokenIDs(uint256 cID, uint256 collectibleCount, uint256 editions) private {
    Storage storage ds = packStorage();

    for (uint256 i = 0; i < editions; i++) {
      uint64 tokenID = uint64((cID + 1) * 100000000) + uint64((collectibleCount + 1) * 100000) + uint64(i + 1);
      ds.collection[cID].shuffleIDs.push(tokenID);
    }
  }

  function createNewCollection(
    string memory _baseURI,
    bool _editioned,
    uint256[] memory _initParams,
    string memory _licenseURI,
    address _mintPass,
    uint256 _mintPassDuration,
    bool[] memory _mintPassParams
  ) external onlyDAO {
    require(_initParams[1] <= 50, "Bulk buy limit of 50");
    Storage storage ds = packStorage();

    ds.collection[ds.collectionCount].baseURI = _baseURI;
    ds.collection[ds.collectionCount].editioned = _editioned;
    ds.collection[ds.collectionCount].tokenPrice = _initParams[0];
    ds.collection[ds.collectionCount].bulkBuyLimit = _initParams[1];
    ds.collection[ds.collectionCount].saleStartTime = _initParams[2];
    ds.collection[ds.collectionCount].licenseURI[0] = _licenseURI;
    ds.collection[ds.collectionCount].licenseVersion = 1;

    if (_mintPass != address(0)) {
      ds.collection[ds.collectionCount].mintPass = true;
      ds.collection[ds.collectionCount].mintPassContract = ERC721(_mintPass);
      ds.collection[ds.collectionCount].mintPassDuration = _mintPassDuration;
      ds.collection[ds.collectionCount].mintPassOnePerWallet = _mintPassParams[0];
      ds.collection[ds.collectionCount].mintPassOnly = _mintPassParams[1];
      ds.collection[ds.collectionCount].mintPassFree = _mintPassParams[2];
      ds.collection[ds.collectionCount].mintPassBurn = _mintPassParams[3];
    } else {
      ds.collection[ds.collectionCount].mintPass = false;
      ds.collection[ds.collectionCount].mintPassDuration = 0;
      ds.collection[ds.collectionCount].mintPassOnePerWallet = false;
      ds.collection[ds.collectionCount].mintPassOnly = false;
      ds.collection[ds.collectionCount].mintPassFree = false;
      ds.collection[ds.collectionCount].mintPassBurn = false;
    }

    ds.collectionCount++;

    emit LogCreateNewCollection(ds.collectionCount);
  }

  // Add single collectible asset with main info and metadata properties
  function addCollectible(uint256 cID, string[] memory _coreData, string[] memory _assets, string[][] memory _metadataValues, string[][] memory _secondaryMetadata, Fee[] memory _fees) external onlyDAO {
    Storage storage ds = packStorage();

    Collection storage collection = ds.collection[cID];
    uint256 collectibleCount = collection.collectibleCount;

    uint256 sum = 0;
    for (uint256 i = 0; i < _fees.length; i++) {
      require(_fees[i].recipient != address(0x0), "Recipient should be present");
      require(_fees[i].value != 0, "Fee value should be positive");
      collection.secondaryFees[collectibleCount].push(Fee({
        recipient: _fees[i].recipient,
        value: _fees[i].value
      }));
      sum = sum.add(_fees[i].value);
    }

    require(sum < 10000, "Fee should be less than 100%");
    require(safeParseInt(_coreData[2]) > 0, "NFTs for given asset must be greater than 0");
    require(safeParseInt(_coreData[3]) > 0 && safeParseInt(_coreData[3]) <= _assets.length, "Version cannot exceed asset count");

    collection.collectibles[collectibleCount] = SingleCollectible({
      title: _coreData[0],
      description: _coreData[1],
      count: safeParseInt(_coreData[2]),
      assets: _assets,
      currentVersion: safeParseInt(_coreData[3]),
      totalVersionCount: _assets.length
    });

    string[] memory propertyNames = new string[](_metadataValues.length);
    string[] memory propertyValues = new string[](_metadataValues.length);
    bool[] memory modifiables = new bool[](_metadataValues.length);
    for (uint256 i = 0; i < _metadataValues.length; i++) {
      propertyNames[i] = _metadataValues[i][0];
      propertyValues[i] = _metadataValues[i][1];
      modifiables[i] = (keccak256(abi.encodePacked((_metadataValues[i][2]))) == keccak256(abi.encodePacked(('1')))); // 1 is modifiable, 0 is permanent
    }

    collection.metadata[collectibleCount] = Metadata({
      name: propertyNames,
      value: propertyValues,
      modifiable: modifiables,
      propertyCount: _metadataValues.length
    });

    propertyNames = new string[](_secondaryMetadata.length);
    propertyValues = new string[](_secondaryMetadata.length);
    modifiables = new bool[](_secondaryMetadata.length);
    for (uint256 i = 0; i < _secondaryMetadata.length; i++) {
      propertyNames[i] = _secondaryMetadata[i][0];
      propertyValues[i] = _secondaryMetadata[i][1];
      modifiables[i] = (keccak256(abi.encodePacked((_secondaryMetadata[i][2]))) == keccak256(abi.encodePacked(('1')))); // 1 is modifiable, 0 is permanent
    }

    collection.secondaryMetadata[collectibleCount] = Metadata({
      name: propertyNames,
      value: propertyValues,
      modifiable: modifiables,
      propertyCount: _secondaryMetadata.length
    });

    uint256 editions = safeParseInt(_coreData[2]);
    createTokenIDs(cID, collectibleCount, editions);

    collection.collectibleCount++;
    collection.totalTokenCount = collection.totalTokenCount.add(editions);

    emit LogAddCollectible(cID, _coreData[0]);
  }

  function checkTokensForMintPass(uint256 cID, address minter, address contractAddress) private returns (bool) {
    Storage storage ds = packStorage();
    uint256 count = ds.collection[cID].mintPassContract.balanceOf(minter);
    bool done = false;
    uint256 counter = 0;
    bool canClaim = false;
    while (!done && count > 0) {
      uint256 tokenID = ds.collection[cID].mintPassContract.tokenOfOwnerByIndex(minter, counter);
      if (ds.collection[cID].mintPassClaims[tokenID] != true) {
        ds.collection[cID].mintPassClaims[tokenID] = true;
        done = true;
        canClaim = true;
        if (ds.collection[cID].mintPassBurn) {
          ds.collection[cID].mintPassContract.safeTransferFrom(msg.sender, address(0xdEaD), tokenID);
        }
      }

      if (counter == count - 1) done = true;
      else counter++;
    }

    return canClaim;
  }

  function checkMintPass(address relics, uint256 cID, address user, address contractAddress) external relicSafety(relics) returns (bool) {
    Storage storage ds = packStorage();

    bool canMintPass = false;
    if (ds.collection[cID].mintPass) {
      if (!ds.collection[cID].mintPassOnePerWallet || !ds.collection[cID].mintPassClaimed[user]) {
        if (checkTokensForMintPass(cID, user, contractAddress)) {
          canMintPass = true;
          if (ds.collection[cID].mintPassOnePerWallet) ds.collection[cID].mintPassClaimed[user] = true;
        }
      }
    }

    if (ds.collection[cID].mintPassOnly) {
      require(canMintPass, "Minting is restricted to mint passes only");
      require(block.timestamp > ds.collection[cID].saleStartTime - ds.collection[cID].mintPassDuration, "Sale has not yet started");
    } else {
      if (canMintPass) require (block.timestamp > (ds.collection[cID].saleStartTime - ds.collection[cID].mintPassDuration), "Sale has not yet started");
      else require(block.timestamp > ds.collection[cID].saleStartTime, "Sale has not yet started");
    }

    return canMintPass;
  }

  function bulkMintChecks(uint256 cID, uint256 amount) external {
    Storage storage ds = packStorage();

    require(amount > 0, 'Missing amount');
    require(!ds.collection[cID].mintPassOnly, 'Cannot bulk mint');
    require(amount <= ds.collection[cID].bulkBuyLimit, "Cannot bulk buy more than the preset limit");
    require(amount <= ds.collection[cID].shuffleIDs.length, "Total supply reached");
    require((block.timestamp > ds.collection[cID].saleStartTime), "Sale has not yet started");
  }

  function mintPassClaimed(uint256 cID, uint256 tokenId) public view returns (bool) {
    Storage storage ds = packStorage();
    return (ds.collection[cID].mintPassClaims[tokenId] == true);
  }

  function tokensClaimable(uint256 cID, address minter) public view returns (uint256[] memory) {
    Storage storage ds = packStorage();

    uint256 count = ds.collection[cID].mintPassContract.balanceOf(minter);
    bool done = false;
    uint256 counter = 0;
    uint256 index = 0;
    uint256[] memory claimable = new uint256[](count);
    while (!done && count > 0) {
      uint256 tokenID = ds.collection[cID].mintPassContract.tokenOfOwnerByIndex(minter, counter);
      if (ds.collection[cID].mintPassClaims[tokenID] != true) {
        claimable[index] = tokenID;
        index++;
      }

      if (counter == count - 1) done = true;
      else counter++;
    }

    return claimable;
  }

  function remainingTokens(uint256 cID) public view returns (uint256) {
    Storage storage ds = packStorage();
    return ds.collection[cID].shuffleIDs.length;
  }

  // Modify property field only if marked as updateable
  function updateMetadata(uint256 cID, uint256 collectibleId, uint256 propertyIndex, string memory value) external onlyDAO {
    Storage storage ds = packStorage();
    require(ds.collection[cID].metadata[collectibleId - 1].modifiable[propertyIndex], 'Field not editable');
    ds.collection[cID].metadata[collectibleId - 1].value[propertyIndex] = value;
    emit LogUpdateMetadata(cID, collectibleId, propertyIndex, value);
  }

  // Add new asset, does not automatically increase current version
  function addVersion(uint256 cID, uint256 collectibleId, string memory asset) public onlyDAO {
    Storage storage ds = packStorage();
    ds.collection[cID].collectibles[collectibleId - 1].assets[ds.collection[cID].collectibles[collectibleId - 1].totalVersionCount - 1] = asset;
    ds.collection[cID].collectibles[collectibleId - 1].totalVersionCount++;
    emit LogAddVersion(cID, collectibleId, asset);
  }

  // Set version number, index starts at version 1, collectible 1 (so shifts 1 for 0th index)
  // function updateVersion(uint256 cID, uint256 collectibleId, uint256 versionNumber) public onlyDAO {
  //   Storage storage ds = packStorage();

  //   require(versionNumber > 0, "Versions start at 1");
  //   require(versionNumber <= ds.collection[cID].collectibles[collectibleId - 1].assets.length, "Versions must be less than asset count");
  //   require(collectibleId > 0, "Collectible IDs start at 1");
  //   ds.collection[cID].collectibles[collectibleId - 1].currentVersion = versionNumber;
  //   emit LogUpdateVersion(cID, collectibleId, versionNumber);
  // }

  // Adds new license and updates version to latest
  function addNewLicense(uint256 cID, string memory _license) public onlyDAO {
    Storage storage ds = packStorage();
    require(cID < ds.collectionCount, 'Collectible ID does not exist');
    ds.collection[cID].licenseURI[ds.collection[cID].licenseVersion] = _license;
    ds.collection[cID].licenseVersion++;
    emit LogAddNewLicense(cID, _license);
  }

  function getLicense(uint256 cID, uint256 versionNumber) public view returns (string memory) {
    Storage storage ds = packStorage();
    return ds.collection[cID].licenseURI[versionNumber - 1];
  }

  function getCurrentLicense(uint256 cID) public view returns (string memory) {
    Storage storage ds = packStorage();
    return ds.collection[cID].licenseURI[ds.collection[cID].licenseVersion - 1];
  }

  // Dynamic base64 encoded metadata generation using on-chain metadata and edition numbers
  function tokenURI(uint256 tokenId) public view returns (string memory) {
    Storage storage ds = packStorage();

    uint256 edition = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 5, bytes(toString(tokenId)).length)) - 1;
    uint256 collectibleId = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 8, bytes(toString(tokenId)).length - 5)) - 1;
    uint256 cID = ((tokenId - ((collectibleId + 1) * 100000)) - (edition + 1)) / 100000000 - 1;
    string memory encodedMetadata = '';

    Collection storage collection = ds.collection[cID];

    for (uint i = 0; i < collection.metadata[collectibleId].propertyCount; i++) {
      encodedMetadata = string(abi.encodePacked(
        encodedMetadata,
        '{"trait_type":"',
        collection.metadata[collectibleId].name[i],
        '", "value":"',
        collection.metadata[collectibleId].value[i],
        '", "permanent":"',
        collection.metadata[collectibleId].modifiable[i] ? 'false' : 'true',
        '"}',
        i == collection.metadata[collectibleId].propertyCount - 1 ? '' : ',')
      );
    }

    string memory encodedSecondaryMetadata = '';
    for (uint i = 0; i < collection.secondaryMetadata[collectibleId].propertyCount; i++) {
      encodedSecondaryMetadata = string(abi.encodePacked(
        encodedSecondaryMetadata,
        '{"trait_type":"',
        collection.secondaryMetadata[collectibleId].name[i],
        '", "value":"',
        collection.secondaryMetadata[collectibleId].value[i],
        '", "permanent":"',
        collection.secondaryMetadata[collectibleId].modifiable[i] ? 'false' : 'true',
        '"}',
        i == collection.secondaryMetadata[collectibleId].propertyCount - 1 ? '' : ',')
      );
    }

    SingleCollectible storage collectible = collection.collectibles[collectibleId];
    uint256 asset = collectible.currentVersion - 1;
    string memory encoded = string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                collectible.title,
                collection.editioned ? ' #' : '',
                collection.editioned ? toString(edition + 1) : '',
                '", "description":"',
                collectible.description,
                '", "image": "',
                collection.baseURI,
                collectible.assets[asset],
                '", "license": "',
                getCurrentLicense(cID),
                '", "attributes": [',
                encodedMetadata,
                '], "secondaryAttributes": [',
                encodedSecondaryMetadata,
                '] }'
              )
            )
          )
        )
      );

    return encoded;
  }

  // Secondary sale fees apply to each individual collectible ID (will apply to a range of tokenIDs);
  function getFeeRecipients(uint256 tokenId) public view returns (address payable[] memory) {
    Storage storage ds = packStorage();

    uint256 edition = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 5, bytes(toString(tokenId)).length)) - 1;
    uint256 collectibleId = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 8, bytes(toString(tokenId)).length - 5)) - 1;
    uint256 cID = ((tokenId - ((collectibleId + 1) * 100000)) - (edition + 1)) / 100000000 - 1;
    Fee[] memory _fees = ds.collection[cID].secondaryFees[collectibleId];
    address payable[] memory result = new address payable[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].recipient;
    }
    return result;
  }

  function getFeeBps(uint256 tokenId) public view returns (uint[] memory) {
    Storage storage ds = packStorage();

    uint256 edition = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 5, bytes(toString(tokenId)).length)) - 1;
    uint256 collectibleId = safeParseInt(substring(toString(tokenId), bytes(toString(tokenId)).length - 8, bytes(toString(tokenId)).length - 5)) - 1;
    uint256 cID = ((tokenId - ((collectibleId + 1) * 100000)) - (edition + 1)) / 100000000 - 1;
    Fee[] memory _fees = ds.collection[cID].secondaryFees[collectibleId];
    uint[] memory result = new uint[](_fees.length);
    for (uint i = 0; i < _fees.length; i++) {
      result[i] = _fees[i].value;
    }

    return result;
  }

  function royaltyInfo(uint256 tokenId, uint256 value) public view returns (address recipient, uint256 amount){
    address payable[] memory rec = getFeeRecipients(tokenId);
    require(rec.length <= 1, "More than 1 royalty recipient");

    if (rec.length == 0) return (address(this), 0);
    return (rec[0], getFeeBps(tokenId)[0] * value / 10000);
  }

  function toString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
        return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
        digits++;
        temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    uint256 index = digits - 1;
    temp = value;
    while (temp != 0) {
        buffer[index--] = bytes1(uint8(48 + temp % 10));
        temp /= 10;
    }
    return string(buffer);
  }

  function safeParseInt(string memory _a) internal pure returns (uint _parsedInt) {
    return safeParseInt(_a, 0);
  }

  function safeParseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
    bytes memory bresult = bytes(_a);
    uint mint = 0;
    bool decimals = false;
    for (uint i = 0; i < bresult.length; i++) {
      if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
        if (decimals) {
            if (_b == 0) break;
            else _b--;
        }
        mint *= 10;
        mint += uint(uint8(bresult[i])) - 48;
      } else if (uint(uint8(bresult[i])) == 46) {
        require(!decimals, 'More than one decimal encountered in string!');
        decimals = true;
      } else {
        revert("Non-numeral character encountered in string!");
      }
    }
    if (_b > 0) {
      mint *= 10 ** _b;
    }
    return mint;
  }

  function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex-startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
  }
}
