// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";

import "../../../interfaces/gov/ERC721/experts/IERC721Expert.sol";

contract ERC721Expert is IERC721Expert, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    uint256 internal constant MAX_TAG_LENGTH = 3;

    uint256 private _maxIssued;

    mapping(address => uint256) private _attachments;
    mapping(uint256 => string[]) private _tags;

    function __ERC721Expert_init(
        string calldata name,
        string calldata symbol
    ) external initializer {
        __Ownable_init();
        __ERC721_init(name, symbol);
    }

    function mint(address to, string calldata uri_) external onlyOwner returns (uint256 tokenId) {
        require(!isExpert(to), "ERC721Expert: Cannot mint more than one expert badge");

        tokenId = ++_maxIssued;

        _mint(to, tokenId);
        _setTokenURI(tokenId, uri_);
        _attachments[to] = tokenId;

        emit Issued(owner(), to, tokenId, BurnAuth.OwnerOnly);
    }

    function burn(address from) external onlyOwner {
        uint256 tokenId = _attachments[from];

        require(tokenId != 0, "ERC721Expert: Cannot burn non-existent badge");

        delete _attachments[from];
        delete _tags[tokenId];

        _burn(tokenId);
    }

    // @dev Tags are memory for storage compatibility
    function setTags(uint256 tokenId, string[] memory tags) external onlyOwner {
        require(_exists(tokenId), "ERC721Expert: Cannot set tags to non-existent badge");
        require(tags.length <= MAX_TAG_LENGTH, "ERC721Expert: Too much tags");

        _tags[tokenId] = tags;

        emit TagsAdded(tokenId, tags);
    }

    function setTokenURI(uint256 tokenId, string calldata uri_) external onlyOwner {
        _setTokenURI(tokenId, uri_);
    }

    function getIdByExpert(address expert) external view returns (uint256) {
        require(isExpert(expert), "ERC721Expert: User is not an expert");

        return _attachments[expert];
    }

    function getTags(uint256 tokenId) external view returns (string[] memory) {
        return _tags[tokenId];
    }

    function burnAuth(uint256 tokenId) external view override returns (BurnAuth) {
        require(_exists(tokenId), "ERC721Expert: Cannot find Burn Auth for non existant badge");

        return BurnAuth.OwnerOnly;
    }

    function isExpert(address expert) public view returns (bool) {
        return balanceOf(expert) == 1;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721URIStorageUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == bytes4(0x0489b56f) || // EIP-5484
            interfaceId == type(IERC721Expert).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _transfer(address, address, uint256) internal pure override {
        revert("ERC721Expert: Expert badge cannot be transferred");
    }
}
