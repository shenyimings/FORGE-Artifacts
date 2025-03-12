// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/ISoulSBTQuest.sol";
import "./interfaces/ISoulSBTQuestErrors.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC721, ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";


/// @title Implementation contract of  growth type SBT developed by SoulSociety
/// @notice As an implementation of ISoulSocietySBT, only the owner can modify growth.
contract SoulSBTQuest is ISoulSBTQuest,  ISoulSBTQuestErrors , ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 private _nextTokenId = 1;

    // The number of users who own SBT.
    uint256 private _totalUser;

    // Total number of Quest Process
    uint256 private _totalCompletionCount;

    // Total number of GrowUp
    uint256 private _totalGrowUpCount;

    struct SBTTracker {
        uint256 growth;
        uint256[] count;
        uint256 totalCount;
        uint256 tokenType;
    }

    // Mapping from owner to information open flag
    mapping(address => bool) private _userProtects;

    // Mapping from owner to list of owned token tokenId, approvalUpdateGrowth
    mapping(address => mapping(uint256 => bool)) private _approvalUpdateGrowth;

    // Mapping from owner to list of owned tokey Types , address, tokenType, tokenId
    mapping(address => mapping(uint256 => uint256)) private _ownedTokensByTypes;

    // questId(SBT ID), SBTTracker
    mapping(uint256 => SBTTracker) private _sbtTracker;

    constructor() ERC721("Token HON SBT", "HONSBT") Ownable(msg.sender) {
        emit ContractCreated(msg.sender,  block.timestamp, name(), symbol());
    }

   // ------------------------------------------------------------------------
    // Permission settings to check the view information of a token
    // ------------------------------------------------------------------------
    function setProtected( bool isProtected_) external  returns (bool) {
        if (!(balanceOf(msg.sender) > 0)) {
        revert SoulSBTQuestNonExist(msg.sender);
        }

        _userProtects[msg.sender] = isProtected_;

        return getProtected(msg.sender);
    }

    function setApprovalGrowth(uint256 tokenId_, bool approved_) external {
        if (!(balanceOf(msg.sender) > 0)) {
            revert SoulSBTQuestNonExist(msg.sender);
        }
        _setApprovalGrowth( tokenId_, approved_);
    }

    // -------------------------------------------------------------------------
    // Mint & Increase
    // -------------------------------------------------------------------------
    function mint(address to_ , uint256 tokenType_) external virtual onlyOwner returns(uint256) {
        uint256 currentTokenId = _nextTokenId;

        _sbtMint(to_, currentTokenId, tokenType_);

        _nextTokenId++;

        return currentTokenId;
    }

    // A function that increase SBT processed count
    function increaseCompletion(uint256 tokenId_) external  onlyOwner returns(uint256) {
        return _increaseCompletion(tokenId_);
    }

    // A function that grows the SBT you have
    function growUp(uint tokenId_) external  onlyOwner returns(uint256) {
        address to = ownerOf(tokenId_);

        if (!_getApprovalGrowth(to, tokenId_)) {
            revert SoulSBTQuestPermissionDenied(to, tokenId_);
        }

        return _growUpById(to, tokenId_);        
    }

    function reset(uint256 tokenId_) external onlyOwner {
        address to = ownerOf(tokenId_);

        if (!_getApprovalGrowth(to, tokenId_)) {
            revert SoulSBTQuestPermissionDenied(to, tokenId_);
        }

        _setGrowthToZero(to, tokenId_);
    }

   function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _isProtectedTokenId(tokenId);

        return super.tokenURI(tokenId);
    }

    function totalUser() external view  returns (uint256) {
        return _totalUser;
    }

    function totalCompletionCount() external view returns (uint256) {
        return _totalCompletionCount;
    }

    function totalGrouwUpCount() external view returns (uint256) {
        return _totalGrowUpCount;
    }

    function getTokenType(uint256 tokenId_) external view returns (uint256) {
         _isProtectedTokenId(tokenId_);

        return _sbtTracker[tokenId_].tokenType;
    }

    function getTokenId(address to_, uint256 tokenType_) external view returns(uint256) {
        _isProtected(to_);

        return _getTokenId(to_, tokenType_);
    }

    function getCompletionCount(uint256 tokenId_) external view returns (uint256) {
        _isProtectedTokenId(tokenId_);

        return  _sbtTracker[tokenId_].totalCount;
    }

    function getCompletionCountByGrowth(uint256 tokenId_, uint256 growth_) external view returns (uint256) {
        _isProtectedTokenId(tokenId_);

        if (_sbtTracker[tokenId_].growth < growth_)
            return 0;

        return _sbtTracker[tokenId_].count[growth_];
    }

    
    function getGrowth(uint256 tokenId_) external view  returns (uint256) {
        _isProtectedTokenId(tokenId_);

        return _sbtTracker[tokenId_].growth;
    }

    function isProtected(address to_) external view returns (bool) {
        return _isProtected(to_);
    }

    function getApprovalGrowth(address owner_, uint256 tokenId_ ) external view returns(bool) {
        return _getApprovalGrowth(owner_, tokenId_);
    } 


    /**
     *  Does not provide a transfer feature.
     */
    function safeTransferFrom(address  , address  , uint256  , bytes memory ) override(ERC721, IERC721) public pure {
        revert SoulSBTQuestNotSupported("safeTransferFrom");
    }

    function transferFrom(address , address , uint256 ) override(ERC721, IERC721) public pure {
        revert SoulSBTQuestNotSupported("transferFrom");
    }

    function approve(address , uint256 ) override(ERC721, IERC721) public pure{
        revert SoulSBTQuestNotSupported("approve");
    }

    function setApprovalForAll(address , bool ) override(ERC721, IERC721) public pure {
        revert SoulSBTQuestNotSupported("setApprovalForAll");
    }

    function getApproved(uint256 ) override(ERC721, IERC721) public pure returns (address )  {
        revert SoulSBTQuestNotSupported("getApproved");
    }

    function isApprovedForAll(address , address ) override(ERC721, IERC721) public pure returns (bool) {
        revert SoulSBTQuestNotSupported("isApprovedForAll");
    }

    function _sbtMint(address to_, uint256 tokenId_, uint256 tokenType_) internal virtual returns(uint256) {
        if (to_ == address(0)) {
            revert SoulSBTQuestInvalidReceiver(address(0));
        }

        if (_exists(tokenId_)) {
            revert SoulSBTQuestExistToken(tokenId_);
        }

        // if to is false , to address is new user
        if(!_existsOwner(to_)) {
            _totalUser += 1;
        }

        if (_ownedTokensByTypes[to_][tokenType_] != 0) {
            revert SoulSBTQuestExistToken(tokenId_);
        }
        
        _ownedTokensByTypes[to_][tokenType_] = tokenId_;

        // _userProtects[to_] = false; default value is false
        _approvalUpdateGrowth[to_][tokenId_] = true;

        // GrowthCounter 구조체를 매핑에 직접 초기화하고 할당
        _sbtTracker[tokenId_] = SBTTracker({
            growth: 0,
            count: new uint256[](1), // 길이가 1인 배열로 초기화
            totalCount: 0,
            tokenType : tokenType_
        });

        // 바로 매핑에서 참조하여 count 배열에 값을 추가
        _sbtTracker[tokenId_].count[0] = 0;

        _safeMint(to_, tokenId_);

        emit Mint(address(0), to_, tokenId_, tokenType_);

        return tokenId_;
    }

    function _growUpById(address to_, uint256 tokenId_) internal returns(uint256) {

        // check to exist and owner address
        _requireMintedOf(to_, tokenId_);
        
        SBTTracker storage curTracker = _sbtTracker[tokenId_];

        curTracker.growth += 1;

        _totalGrowUpCount++;

        uint256 tokenGrowth = curTracker.growth;

        if (curTracker.count.length <= tokenGrowth)
            curTracker.count.push(0);

        emit GrowUp(to_, tokenId_, tokenGrowth);

        return tokenGrowth;
    }

    function _setGrowthToZero(address to_, uint tokenId_) internal  {
        // check to exist and owner address
        _requireMintedOf(to_, tokenId_);

        SBTTracker storage curTracker = _sbtTracker[tokenId_];

        for (uint i = 0; i < curTracker.count.length; i++) {
            curTracker.count[i] = 0;
        }

        curTracker.growth = 0;
        curTracker.totalCount = 0;

        emit Reset(to_, tokenId_);
    }

    function _increaseCompletion(uint256 tokenId_) internal returns(uint256) {
        // check to exist and owner address
        _requireMinted(tokenId_);

        SBTTracker storage curTracker = _sbtTracker[tokenId_];

        uint256 curGrowth = curTracker.growth;

        curTracker.count[curGrowth] += 1;
        curTracker.totalCount += 1;
        
        // _questCounter[tokenType_][to_] += 1;

        _totalCompletionCount += 1;

        uint256 increasedCount = curTracker.count[curGrowth];


        emit IncreaseCompletion(tokenId_,  increasedCount);

        return increasedCount;
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
            revert SoulSBTQuestProtectedOwner(to_);
        
        return false;
    }

    function _isProtectedTokenId(uint256 tokenId_) internal view {
        // If tokenId doesn't exist,  don't need to check "protected status"
        if (!_exists(tokenId_)) {
            revert SoulSBTQuestNonexistentToken(tokenId_);
        }

        _isProtected(ownerOf(tokenId_));
    }

    function _setApprovalGrowth(uint256 tokenId_, bool approved_) internal {
        _approvalUpdateGrowth[msg.sender][tokenId_] = approved_;
    }

    function _getApprovalGrowth(address owner_, uint256 tokenId_) internal view returns(bool) {
        return _approvalUpdateGrowth[owner_][tokenId_];
    }


    /**
     * @dev Returns whether `tokenId` exists.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function _existsOwner(address to) internal view virtual returns (bool) {
        return balanceOf(to) != 0;
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId_) internal view virtual {
        if (!_exists(tokenId_)) {
            revert SoulSBTQuestNonexistentToken(tokenId_);
        }
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet and owner address is not equal "to" address
     */
    function _requireMintedOf(address to_, uint256 tokenId_) internal view virtual {
        if(_ownerOf(tokenId_) != to_) {
            revert SoulSBTQuestInvalidOwner(to_);
        }
    }

    function _getTokenId(address to_, uint256 tokenType_) internal view returns(uint256) {
        uint256 tokenId = _ownedTokensByTypes[to_][tokenType_];

        _requireMinted(tokenId);
        
        return tokenId;
    }

    function isContract(address addr_) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr_)
        }
        return (size > 0);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal  pure  override  returns (string memory)  {
        return "https://api.soulsociety.gg/sbt/";
    }
//    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool)
//    {
//        if (!isContract(to)) {
//            return true;
//        }
//        bytes4 retval = IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data);
//        return (retval == IERC721Receiver(to).onERC721Received.selector);
//    }

}