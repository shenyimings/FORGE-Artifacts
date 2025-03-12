/* SPDX-License-Identifier: MIT */

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./ERC721Tradable.sol";

contract WeAllSurvivedDeath is
    AccessControl,
    ERC721Burnable,
    ERC721Tradable,
    IERC721Enumerable
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    struct TokenInfo {
        uint256 tokenId;
        string tokenURI;
    }

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _currentId;
    string private _baseTokenURI;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from an owner address and the token index to the token ID
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Mapping from token ID to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address proxyRegistryAddress
    ) ERC721Tradable(name_, symbol_, proxyRegistryAddress) {
        _baseTokenURI = baseTokenURI_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _currentId.increment();
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        override(IERC721, ERC721, ERC721Tradable)
        returns (bool)
    {
        return ERC721Tradable.isApprovedForAll(owner, operator);
    }

    function baseTokenURI() public view override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721Tradable)
        returns (string memory)
    {
        require(_exists(tokenId), "WeAllSurvivedDeath: token does not exist");
        return
            string(
                abi.encodePacked(
                    _baseTokenURI,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        require(
            index < ERC721.balanceOf(owner),
            "WeAllSurvivedDeath: owner index out of bounds"
        );
        return _ownedTokens[owner][index];
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC721Tradable, IERC721Enumerable)
        returns (uint256)
    {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        require(
            index < totalSupply(),
            "WeAllSurvivedDeath: global index out of bounds"
        );
        return _allTokens[index];
    }

    function getOwnedTokens(
        address user,
        uint256 fromIndex,
        uint256 toIndex
    ) external view returns (TokenInfo[] memory) {
        if (balanceOf(user) == 0) return new TokenInfo[](0);
        uint256 lastIndex = toIndex;
        if (lastIndex >= balanceOf(user)) lastIndex = balanceOf(user) - 1;
        require(
            fromIndex <= lastIndex,
            "WeAllSurvivedDeath: invalid query range"
        );
        uint256 numNFTs = lastIndex - fromIndex + 1;
        TokenInfo[] memory ownedTokens = new TokenInfo[](numNFTs);
        for (uint256 i = fromIndex; i <= lastIndex; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(user, i);
            ownedTokens[i - fromIndex] = TokenInfo(tokenId, tokenURI(tokenId));
        }
        return ownedTokens;
    }

    function setBaseTokenURI(string memory baseTokenURI_) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "WeAllSurvivedDeath: caller is not admin"
        );
        _baseTokenURI = baseTokenURI_;
    }

    function mintTo(address to) public override {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "WeAllSurvivedDeath: must have minter role to mint"
        );
        uint256 currentTokenId = _currentId.current();
        _currentId.increment();
        _safeMint(to, currentTokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Enumerable).interfaceId ||
            AccessControl.supportsInterface(interfaceId) ||
            ERC721.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
        if (from == address(0)) _addTokenToAllTokensEnumeration(tokenId);
        else if (from != to) _removeTokenFromOwnerEnumeration(from, tokenId);
        if (to == address(0)) _removeTokenFromAllTokensEnumeration(tokenId);
        else if (to != from) _addTokenToOwnerEnumeration(to, tokenId);
    }

    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId)
        private
    {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }

    function _msgSender()
        internal
        view
        override(Context, ERC721Tradable)
        returns (address)
    {
        return ERC721Tradable._msgSender();
    }
}
