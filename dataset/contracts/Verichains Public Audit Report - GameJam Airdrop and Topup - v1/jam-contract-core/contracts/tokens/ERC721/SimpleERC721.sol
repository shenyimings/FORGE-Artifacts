/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleERC721 is ERC721Enumerable, Ownable, IERC2981 {
    using SafeMath for uint256;
    uint256 _tokenIds;
    string public tokenURIPrefix =
        "https://asset.gamejam.co/gamejam-nft/erc721/unique/";
    string public tokenURISuffix = ".json";
    address public nftAddress;

    mapping(uint256 => address) public firstOwner;

    // royalty fee takes on each auction, measured in basis points (1/100 of a percent).
    // Values 0-10,00 map to 0%-10%
    uint64 public royaltyFee;

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event AwardItem(address indexed player, uint256 indexed tokenId);

    /**
     * @dev Emitted when owner of contract update royaltyFee from `previous_fee` to `current_fee`
     */
    event UpdateRoyaltyFee(uint64 previous_fee, uint64 current_fee);

    constructor(
        address _owner,
        string memory name,
        string memory symbol,
        string memory _tokenURIPrefix
    ) payable ERC721(name, symbol) {
        transferOwnership(payable(_owner));
        nftAddress = address(this);
        tokenURIPrefix = _tokenURIPrefix;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, IERC165)
        returns (bool)
    {
        bool b = interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            (interfaceId == type(IERC2981).interfaceId && royaltyFee > 0) ||
            super.supportsInterface(interfaceId);
        return b;
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        virtual
        override(IERC2981)
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = firstOwner[tokenId];
        royaltyAmount = salePrice.mul(royaltyFee).div(10000);
        return (receiver, royaltyAmount);
    }

    function setRoyaltyFee(uint64 _royaltyFee) public onlyOwner {
        require(
            _royaltyFee <= 1000,
            "SimpleERC721: royalty fee must not exceed 10%"
        );
        uint64 previousFee = royaltyFee;
        royaltyFee = _royaltyFee;
        emit UpdateRoyaltyFee(previousFee, royaltyFee);
    }

    function setTokenURIPrefix(string calldata _tokenURIPrefix)
        public
        onlyOwner
        returns (string calldata)
    {
        tokenURIPrefix = _tokenURIPrefix;
        return _tokenURIPrefix;
    }

    function setTokenURISuffix(string calldata _tokenURISuffix)
        public
        onlyOwner
        returns (string calldata)
    {
        tokenURISuffix = _tokenURISuffix;
        return _tokenURISuffix;
    }

    function awardItem(address player) public onlyOwner returns (uint256) {
        uint256 _ttId = _tokenIds += 1;
        _safeMint(player, _ttId);
        emit AwardItem(player, _ttId);
        firstOwner[_ttId] = player;
        return _ttId;
    }

    function _uintToString(uint256 v) private pure returns (string memory str) {
        uint256 maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint256 i = 0;
        while (v != 0) {
            uint256 remainder = v % 10;
            v = v / 10;
            i++;
            reversed[i] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i + 1);
        for (uint256 j = 0; j <= i; j++) {
            s[j] = reversed[i - j];
        }
        str = string(s);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        bytes memory b;
        b = abi.encodePacked(tokenURIPrefix);
        b = abi.encodePacked(b, _uintToString(_tokenId));
        b = abi.encodePacked(b, tokenURISuffix);
        return string(b);
    }

    function _formatStartIndex(uint256 _from_index)
        private
        pure
        returns (uint256)
    {
        return _from_index > 0 ? _from_index : 0;
    }

    function _formatEndIndex(uint256 _end_index, uint256 _max)
        private
        pure
        returns (uint256)
    {
        return _end_index > _max ? _max : _end_index;
    }

    function tokenOfOwner(
        address owner,
        uint256 _from_index,
        uint256 _end_index
    ) public view returns (uint256[] memory) {
        uint256 totalToken = ERC721.balanceOf(owner);
        _from_index = _formatStartIndex(_from_index);
        _end_index = _formatEndIndex(_end_index, totalToken);
        uint256[] memory tokenIds = new uint256[](_end_index - _from_index);
        for (uint256 i = _from_index; i < _end_index; i += 1) {
            uint256 tmp = ERC721Enumerable.tokenOfOwnerByIndex(owner, i);
            tokenIds[i - _from_index] = tmp;
        }
        return tokenIds;
    }
}
