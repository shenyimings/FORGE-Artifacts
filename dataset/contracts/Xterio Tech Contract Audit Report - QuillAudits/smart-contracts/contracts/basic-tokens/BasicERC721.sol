// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./management/GatewayGuardedOwnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IGateway.sol";
import "./interfaces/IBasicERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC4907.sol";

// For auto-increment ids
import "@openzeppelin/contracts/utils/Counters.sol";

import "operator-filter-registry/src/OperatorFilterer.sol";

contract BasicERC721 is
    IBasicERC721,
    ERC721,
    ERC721Burnable,
    ERC4907,
    GatewayGuardedOwnable,
    Pausable,
    OperatorFilterer
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    uint256 constant VERSION = 20230409;

    Counters.Counter private _tokenIdCounter;

    string private __baseURI;

    /**
     * @param gateway NFTGateway contract of the NFT contract.
     */
    constructor(
        address owner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        address subscriptionOrRegistrantToCopy,
        bool subscribe,
        address gateway
    )
        ERC4907(name, symbol)
        GatewayGuarded(gateway)
        OperatorFilterer(subscriptionOrRegistrantToCopy, subscribe)
    {
        _transferOwnership(owner);
        __baseURI = baseURI;
    }

    /**
     * Mint `tokenId` to `to`. If `tokenId` is 0, use auto-increment id.
     */
    function mint(address to, uint256 tokenId) external override onlyGateway {
        if (tokenId == 0) {
            uint256 id;
            while (true) {
                _tokenIdCounter.increment();
                id = _tokenIdCounter.current();
                if (!_exists(id)) {
                    tokenId = id;
                    break;
                }
            }
        }
        _safeMint(to, tokenId);
    }

    /**
     * Batch mint `tokenId` to `to`.
     */
    function mintBatch(
        address to,
        uint256[] calldata tokenId
    ) external override onlyGateway {
        for (uint256 i = 0; i < tokenId.length; i++) {
            _safeMint(to, tokenId[i]);
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return string(abi.encodePacked(__baseURI, tokenId.toHexString(32)));
    }

    function contractURI() public view returns (string memory) {
        return __baseURI;
    }

    function setURI(string calldata newBaseURI) external override onlyGateway {
        __baseURI = newBaseURI;
    }

    // These functions are overriden for the operator filterer to work
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(
        address operator,
        uint256 tokenId
    ) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view override returns (bool) {
        if (IGateway(gateway).operatorWhitelist(operator)) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function pause() external onlyGateway {
        _pause();
    }

    function unpause() external onlyGateway {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC4907) whenNotPaused {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC4907) returns (bool) {
        return
            interfaceId == type(IBasicERC721).interfaceId ||
            ERC721.supportsInterface(interfaceId) ||
            ERC4907.supportsInterface(interfaceId);
    }
}
