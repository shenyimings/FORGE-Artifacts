// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/ISoulSocietyEnumerableSBT.sol";
import "./interfaces/ISoulSocietySBTMetadata.sol";
import "./interfaces/ISoulSocietySBTErrors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";


/// @title Implementation contract of  growth type SBT developed by SoulSociety
/// @notice As an implementation of ISoulSocietySBT, only the owner can modify growth.
contract SoulSocietySBT is ISoulSocietySBT, ISoulSocietySBTMetadata, ISoulSocietySBTErrors , IERC721, ERC165, Ownable {

    using Strings for uint256;

    // token Name
    string private constant _name = "HONSBT";

    // token Symbol
    string private constant _symbol= "HONSBT";

    // token Meta URI
    string private _uri;

    // The number of users who own SBT.
    uint256 private _totalUser;

    // Total number of SBT issued
    uint256 private _totalCount;

    // Mapping from SBT ID to owned address
    mapping(uint256 => address) private _owners;

    // Mapping from SBT ID to token Type
    mapping(uint256 => uint256) private _tokenTypes;

    // Mapping from SBT ID to current Growth
    mapping(uint256 => uint256) private _tokenGrowths;

    // Mapping from owner to count of SBT 
    mapping(address => uint256) private _balances;

    // Mapping from owner to information open flag
    mapping(address => bool) private _userProtects;

    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from owner to list of owned tokey Types , address, tokenType, tokenId
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensByTypes;

    // Mapping from owner to list of owned token tokenId, approvalUpdateGrowth
    mapping(address => mapping(uint256 => bool)) private _approvalUpdateGrowth;

    constructor(string memory uri_) Ownable(msg.sender) {
        _uri = uri_;

        emit ContractCreated(msg.sender,  block.timestamp, _name, _symbol, uri_);
    }

    // ------------------------------------------------------------
    // Functions related to basic contract information
    // External Interface Implementation
    // ------------------------------------------------------------
    function setTokenURI(string memory tokenURI_) external onlyOwner returns(string memory) {
        _uri = tokenURI_;

        emit SetTokenURI(msg.sender, tokenURI_);

        return _uri;
    }

    // ------------------------------------------------------------------------
    // Permission settings to check the view information of a token
    // ------------------------------------------------------------------------
    function setProtected( bool isProtected_) external  returns (bool) {
        if (!(_balanceOf(msg.sender) > 0)) {
            revert SoulSocietySBTNonExist(msg.sender);
        }

        _userProtects[msg.sender] = isProtected_;

        return getProtected(msg.sender);
    }

    function setApprovalGrowth(uint256 tokenId_, bool approved_) external {
        if (!(_balanceOf(msg.sender) > 0)) {
            revert SoulSocietySBTNonExist(msg.sender);
        }
        _setApprovalGrowth( tokenId_, approved_);
    }

    // -------------------------------------------------------------------------
    // Mint & Grow Up
    // -------------------------------------------------------------------------
    function mint(address to_, uint256 tokenType_) external virtual onlyOwner returns(uint256) {
        return _safeMint(to_, tokenType_);
    }

    function reset(address to_, uint256 tokenId_) external onlyOwner  {
        if (!_getApprovalGrowth(to_, tokenId_)) {
            revert SoulSocietySBTPermissionDenied(to_, tokenId_);
        }
        _setGrowthToZero(to_, tokenId_);
    }

    // A function that grows the SBT you have
    function growUp(address to_, uint256 tokenId_) external  onlyOwner returns(uint256) {
        if (!_getApprovalGrowth(to_, tokenId_)) {
            revert SoulSocietySBTPermissionDenied(to_, tokenId_);
        }

        return _growUp(to_, tokenId_);
    }

    // External View & Pure Functions

    // Token Name
    function name() external pure virtual returns (string memory) {
        return _name;
    }

    // Token Symbol
    function symbol() external pure virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId_) external view virtual  returns (string memory) {    
        // check protected status 
        _isProtectedTokenId(tokenId_);

        return bytes(_uri).length > 0 ? string(abi.encodePacked(_uri, tokenId_.toString(), "?tokenType=", _tokenTypes[tokenId_])) : "";        
    }

    function totalUser() external view  returns (uint256) {
        return _totalUser;
    }

    function totalSupply() external view  returns (uint256) {
        return _totalCount;
    }
 
    function getTokenType(uint256 tokenId_) external view returns (uint256) {

        _isProtectedTokenId(tokenId_);

        return _tokenTypes[tokenId_];
    }

    function getTokenId(address to_, uint256 tokenType_) external view returns(uint256) {
         _isProtected(to_);

        return _ownedTokensByTypes[to_][tokenType_];
    }

    function isProtected(address to_) external view returns (bool) {
        return _isProtected(to_);
    }

    function getApprovalGrowth(address owner_, uint256 tokenId_ ) external view returns(bool) {
        return _getApprovalGrowth(owner_, tokenId_);
    } 

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function ownerOf(uint256 tokenId_) external  view  override  returns (address) {
         // Check whether the token exists and if its status is 'protected'.
        _isProtectedTokenId(tokenId_);

        return _owners[tokenId_];
    }

    function balanceOf(address owner_) external  view  returns (uint256) {
         // Check whether the token exists and if its status is 'protected'.
        _isProtected(owner_);
        
        return _balanceOf(owner_);
    }

    function getGrowth(uint256 tokenId_) external view  returns (uint256) {
        // Check whether the token exists and if its status is 'protected'.
        _isProtectedTokenId(tokenId_);

        return _tokenGrowths[tokenId_];
    }

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner_, uint256 index_) external view returns (uint256) {
        // Check whether the token exists and if its status is 'protected'.
       _isProtected(owner_);

        require(index_ < _balanceOf(owner_), "Out of Index");

        if (owner_ == address(0)) {
            revert SoulSocietySBTInvalidReceiver(address(0));
        }

        uint256 tokenId = _ownedTokens[owner_][index_];

        return tokenId; 
    }

    /**
     *  Does not provide a transfer feature.
     */
    function safeTransferFrom(address , address , uint256 , bytes calldata) external pure {
        revert SoulSocietySBTNotSupported("safeTransferFrom");
    }

    function safeTransferFrom(address , address , uint256 ) external pure {
        revert SoulSocietySBTNotSupported("safeTransferFrom");
    }

    function transferFrom(address , address , uint256 ) external pure {
        revert SoulSocietySBTNotSupported("transferFrom");
    }

    function approve(address , uint256 ) external pure{
        revert SoulSocietySBTNotSupported("approve");
    }

    function setApprovalForAll(address , bool ) external pure {
        revert SoulSocietySBTNotSupported("setApprovalForAll");
    }

    function getApproved(uint256 ) external pure returns (address )  {
        revert SoulSocietySBTNotSupported("getApproved");
    }

    function isApprovedForAll(address , address ) external pure returns (bool) {
        revert SoulSocietySBTNotSupported("isApprovedForAll");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return 
            interfaceId == type(IERC721).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // Internal Functions 
    function _safeMint(address to_, uint256 tokenType_) internal virtual returns(uint256) {
        uint256 tokenId = _mint(to_, tokenType_);
        require(
           _checkOnERC721Received(address(0), to_, tokenId, "Mint SBT"),
           "ERC721: transfer to non ERC721Receiver implementer"
        ); 

        return tokenId;
    }

    function _mint(address to_, uint256 tokenType_) internal virtual returns(uint256) {
        uint256 tokenId = _totalCount + 1;
    
        if (to_ == address(0)) {
            revert SoulSocietySBTInvalidReceiver(address(0));
        }

        if (_exists(tokenId)) {
            revert SoulSocietySBTExistToken(tokenId);
        }

        // if to is false , to address is new user
        if(!_existsOwner(to_)) {
            _totalUser += 1;
        }

        unchecked {
        // Will not overflow unless all 2**256 token ids are minted to the same owner.
        // Given that tokens are minted one by one, it is impossible in practice that
        // this ever happens. Might change if we allow batch minting.
        // The ERC fails to describe this case.
            _balances[to_] += 1;
            _totalCount += 1;
            
        }

        _owners[tokenId] = to_;
        _tokenTypes[tokenId] = tokenType_;
        _tokenGrowths[tokenId] = 1;
        // _userProtects[to_] = false; default value is false
        _approvalUpdateGrowth[to_][tokenId] = true;
        _ownedTokens[to_][_balances[to_]-1] = tokenId; // index from 0
        _ownedTokensByTypes[to_][tokenType_] = tokenId;

        emit Mint(address(0), to_, tokenId, tokenType_);

        return tokenId;
    }


    function _setGrowthToZero(address to_, uint tokenId_) internal  {
        // check to exist and owner address
        _requireMintedOf(to_, tokenId_);

        _tokenGrowths[tokenId_] = 0;

        emit Reset(to_, tokenId_);
    }

    function _growUp(address to_, uint256 tokenId_) internal returns(uint256) {
        
        // check to exist and owner address
        _requireMintedOf(to_, tokenId_);

        _tokenGrowths[tokenId_] += 1;

        uint256 tokenGrowth = _tokenGrowths[tokenId_];

        emit GrowUp(to_, tokenId_, tokenGrowth);

        return tokenGrowth;
    }

    function getProtected(address to_) internal view returns(bool) {
        return _getProtected(to_);
    }

    function _getProtected(address to_) internal  view returns(bool) {
        // If owner doesn't exist, return value is false
        return _userProtects[to_];
    }

    function _isProtected(address to_) internal view returns (bool) {        
        if (_userProtects[to_] == true)
            revert SoulSocietySBTProtectedOwner(to_);
        
        return false;
    }

    function _isProtectedTokenId(uint256 tokenId_) internal view {
        // If tokenId doesn't exist,  don't need to check "protected status"
        if (!_exists(tokenId_)) {
            revert SoulSocietySBTNonexistentToken(tokenId_);
        }

        _isProtected(_owners[tokenId_]);
    }

    function _setApprovalGrowth(uint256 tokenId_, bool approved_) internal {
        _approvalUpdateGrowth[msg.sender][tokenId_] = approved_;
    }

    function _getApprovalGrowth(address owner_, uint256 tokenId_) internal view returns(bool) {
        return _approvalUpdateGrowth[owner_][tokenId_];
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId_) internal view  returns (address) {
        return _owners[tokenId_];
    }

    function _balanceOf(address owner_) internal view returns (uint256) {
            return _balances[owner_];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _existsOwner(address to) internal view virtual returns (bool) {
        return _balances[to] != 0;
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        if (!_exists(tokenId)) {
            revert SoulSocietySBTNonexistentToken(tokenId);
        }
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet and owner address is not equal "to" address
     */
    function _requireMintedOf(address to, uint256 tokenId) internal view virtual {
        if(_ownerOf(tokenId) != to) {
            revert SoulSocietySBTInvalidOwner(to);
        }
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool)
    {
        if (!isContract(to)) {
            return true;
        }
        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
        return (retval == IERC721Receiver(to).onERC721Received.selector);
    }
}