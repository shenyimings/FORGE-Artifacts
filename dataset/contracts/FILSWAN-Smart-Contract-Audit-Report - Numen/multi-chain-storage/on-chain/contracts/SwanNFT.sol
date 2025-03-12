// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract SwanNFT is Initializable, ERC1155Upgradeable, ERC1155SupplyUpgradeable, ERC1155URIStorageUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIdCounter;

    mapping (uint => bool) public isUnique;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC1155_init("");
        __ERC1155Supply_init();
        __ERC1155URIStorage_init();
        __Ownable_init();
    }

    // does not use data parameter
    // mints a new NFT incrementing token ID
    function mintUnique(address account, string memory newUri) public {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        require(!exists(tokenId), 'Supply: tokenId already exists');

        isUnique[tokenId] = true;
        _mint(account, tokenId, 1, "");
        _setURI(tokenId, newUri);
    }

    // mints a new NFT (with data) incrementing tokenID
    function mintUniqueWithData(address account, string memory newUri, bytes memory data) public {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        require(!exists(tokenId), 'Supply: tokenId already exists');

        isUnique[tokenId] = true;
        _mint(account, tokenId, 1, data);
        _setURI(tokenId, newUri);
    }

    // mints a new (non-unqiue) token (with data)
    function mint(address account, uint256 amount, string memory newUri, bytes memory data)
        public
    {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        require(!exists(tokenId), 'Supply: tokenId already exists');

        _mint(account, tokenId, amount, data);
        _setURI(tokenId, newUri);
    }

    // mints more of an existing token (must not be unqiue)
    function mintMore(address account, uint256 id, uint256 amount, bytes memory data)
        public
    {
        require(exists(id), 'Supply: tokenId does not exist');
        require(!isUnique[id], 'Unique: cannot mint more than one');

        _mint(account, id, amount, data);
    }

    // sets URI for existing token if not already set
    function setURI(uint id, string memory newUri) public {
        string memory tokenURI = uri(id);
        require(exists(id), 'Supply: tokenId does not exist');
        require(bytes(tokenURI).length == 0, 'URI: token already has URI set');

        _setURI(id, newUri);
    }

    // overrides

    function uri(uint256 tokenId) public view virtual override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable) returns (string memory) {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
    }
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )internal virtual override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        ERC1155SupplyUpgradeable._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // get the current id count of tokens
    function idCount() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
    
    function contractURI() external pure returns (string memory) {
        return "https://ipfs.multichain.storage/ipfs/QmTnvCrc3U3Df5WEpbtQneChZtRNB4SFbnndQVN6S6rzsd";
    }


}