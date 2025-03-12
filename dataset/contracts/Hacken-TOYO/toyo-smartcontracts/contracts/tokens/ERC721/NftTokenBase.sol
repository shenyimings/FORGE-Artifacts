// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../../@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "../../@rarible/royalties/contracts/LibPart.sol";
import "../../@rarible/royalties/contracts/LibRoyaltiesV2.sol";

abstract contract NftTokenBase is
    ERC721URIStorage,
    ERC721Enumerable,
    ERC721Burnable,
    AccessControl,
    Ownable,
    RoyaltiesV2Impl
{
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // -----------------------------------------
    // Public
    // -----------------------------------------

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        if (interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }

        if (interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    // -----------------------------------------
    // Minter role
    // -----------------------------------------

    function mint(
        address recipient,
        string memory metadata,
        uint256 newItemId
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, metadata);
        return newItemId;
    }

    function mintWithRoyalties(
        address recipient,
        string memory metadata,
        uint256 newItemId,
        address payable _royaltiesRecipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyRole(MINTER_ROLE) returns (uint256) {
        mint(recipient, metadata, newItemId);
        _setRoyalties(
            newItemId,
            _royaltiesRecipientAddress,
            _percentageBasisPoints
        );
        return newItemId;
    }

    // -----------------------------------------
    // OnlyOwner
    // -----------------------------------------

    function setRoyalties(
        uint256 _tokenId,
        address payable _royaltiesRecipientAddress,
        uint96 _percentageBasisPoints
    ) public onlyOwner {
        _setRoyalties(
            _tokenId,
            _royaltiesRecipientAddress,
            _percentageBasisPoints
        );
    }

    // -----------------------------------------
    // External
    // -----------------------------------------

    function getOwnedTokenIds(address _owner) external view returns (uint256[] memory) {
        uint256[] memory ret = new uint256[](balanceOf(_owner));
        for (uint256 i = 0; i < balanceOf(_owner); i++) {
            ret[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return ret;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        LibPart.Part[] memory _royalties = royalties[_tokenId];
        if (_royalties.length > 0) {
            return (
                _royalties[0].account,
                (_salePrice * _royalties[0].value) / 10000
            );
        }
        return (address(0), 0);
    }

    // -----------------------------------------
    // Internal
    // -----------------------------------------

    function _setRoyalties(
        uint256 _tokenId,
        address payable _royaltiesRecipientAddress,
        uint96 _percentageBasisPoints
    ) internal {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesRecipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function burn(uint256 tokenId)
    public
    override(ERC721Burnable)
    {
        super.burn(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function exists(uint256 tokenId)
        external view
    returns (bool)
    {
        return super._exists(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
