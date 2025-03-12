// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@solarity/solidity-lib/utils/BlockGuard.sol";

import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/ERC721/multipliers/IAbstractERC721Multiplier.sol";

import "../../../core/Globals.sol";

abstract contract AbstractERC721Multiplier is
    IAbstractERC721Multiplier,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    BlockGuard
{
    string public constant LOCK_UNLOCK = "LOCK_UNLOCK";

    mapping(uint256 => NftInfo) internal _tokens;
    mapping(address => uint256) internal _latestLockedTokenIds;

    event Minted(uint256 tokenId, address to, uint256 multiplier, uint256 duration);
    event Locked(uint256 tokenId, address sender, bool isLocked);
    event Changed(uint256 tokenId, uint256 multiplier, uint256 duration);

    function __ERC721Multiplier_init(
        string calldata name,
        string calldata symbol
    ) public initializer {
        __Ownable_init();
        __ERC721Enumerable_init();
        __ERC721_init(name, symbol);
    }

    function lock(uint256 tokenId) external {
        _lockBlock(LOCK_UNLOCK, msg.sender);

        _onlyTokenOwner(tokenId);

        require(
            !isLocked(_latestLockedTokenIds[msg.sender]),
            "ERC721Multiplier: Cannot lock more than one nft"
        );

        _latestLockedTokenIds[msg.sender] = tokenId;

        _afterTokenLock(tokenId);

        emit Locked(tokenId, msg.sender, true);
    }

    function unlock() external {
        _checkBlock(LOCK_UNLOCK, msg.sender);

        uint256 tokenId = _latestLockedTokenIds[msg.sender];

        _onlyTokenOwner(tokenId);

        require(
            IGovPool(owner()).getUserActiveProposalsCount(msg.sender) == 0,
            "ERC721Multiplier: Cannot unlock with active proposals"
        );

        delete _latestLockedTokenIds[msg.sender];

        _afterTokenUnlock(tokenId);

        emit Locked(tokenId, msg.sender, false);
    }

    function setTokenURI(uint256 tokenId, string calldata uri_) external onlyOwner {
        _setTokenURI(tokenId, uri_);
    }

    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721URIStorageUpgradeable, ERC721EnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IAbstractERC721Multiplier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function isLocked(uint256 tokenId) public view returns (bool) {
        return tokenId != 0 && _latestLockedTokenIds[ownerOf(tokenId)] == tokenId;
    }

    function _mint(address to, uint256 multiplier, uint64 duration, string memory uri_) internal {
        uint256 currentTokenId = totalSupply() + 1;

        _mint(to, currentTokenId);
        _setTokenURI(currentTokenId, uri_);

        _tokens[currentTokenId] = NftInfo({
            multiplier: multiplier,
            duration: duration,
            mintedAt: uint64(block.timestamp)
        });

        emit Minted(currentTokenId, to, multiplier, duration);
    }

    function _changeToken(uint256 tokenId, uint256 multiplier, uint64 duration) internal {
        _requireMinted(tokenId);

        NftInfo storage token = _tokens[tokenId];

        token.multiplier = multiplier;
        token.duration = duration;

        emit Changed(tokenId, multiplier, duration);
    }

    function _afterTokenLock(uint256 tokenId) internal virtual {}

    function _afterTokenUnlock(uint256 tokenId) internal virtual {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721EnumerableUpgradeable, ERC721Upgradeable) {
        if (from != address(0)) {
            require(!isLocked(tokenId), "ERC721Multiplier: Cannot transfer locked token");
        }

        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721URIStorageUpgradeable, ERC721Upgradeable) {
        ERC721URIStorageUpgradeable._burn(tokenId);
    }

    function _getCurrentMultiplier(
        address whose
    ) internal view returns (uint256 tokenId, uint256 multiplier, uint256 timeLeft) {
        uint256 latestLockedTokenId = _latestLockedTokenIds[whose];

        if (!isLocked(latestLockedTokenId)) {
            return (0, 0, 0);
        }

        NftInfo memory info = _tokens[latestLockedTokenId];

        if (uint256(info.mintedAt) + info.duration < block.timestamp) {
            return (0, 0, 0);
        }

        return (
            latestLockedTokenId,
            info.multiplier,
            info.mintedAt + info.duration - block.timestamp
        );
    }

    function _onlyTokenOwner(uint256 tokenId) internal view {
        require(ownerOf(tokenId) == msg.sender, "ERC721Multiplier: not the nft owner");
    }

    uint256[47] private _gap;
}
