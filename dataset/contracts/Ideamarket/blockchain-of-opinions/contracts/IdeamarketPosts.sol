//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IIdeamarketPosts.sol";
import "./interfaces/IArbSys.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "base64-sol/base64.sol";


/**
 * @title IdeamarketPosts
 * @author Kelton Madden
 *
 * @dev mints erc721 tokens representing "posts" on ideamarket
 */

contract IdeamarketPosts is IIdeamarketPosts, ERC721, AccessControl {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // list of tokenIDs a particular address minted
    mapping(address => uint[]) mintedTokens;
    // metadata for posts by tokenID
    mapping(uint => Post) public posts;
    // mapping of existing category tags
    mapping(string => bool) public categories;
    // categories tagged for a given post
    // tokenID => string => bool
    mapping(uint => mapping(string => bool)) public postCategories;

    // all active categories
    string[] public activeCategories;

    uint tokenNumber;
    // contract to retrieve arb block height
    IArbSys constant _arbSys = IArbSys(address(100));

    constructor(address admin) ERC721("IdeamarketPosts", "IMPOSTS") {
        _setupRole(ADMIN_ROLE, admin);
        bytes32 adminBytes = bytes32(uint256(uint160(admin)) << 96);
        _setupRole(adminBytes, admin);
        _setRoleAdmin(ADMIN_ROLE, adminBytes);
    }
    
    function mint(string calldata content, string[] memory imageHashes, string[] memory categoryTags, string calldata imageLink, 
        bool urlBool, string calldata urlContent, address recipient) external {
        require(bytes(content).length > 0 && bytes(content).length <= 20000, "content-length");
        require(recipient != address(0), "zero-addr");
        
        //uint blockHeight = _arbSys.arbBlockNumber();
        uint blockHeight = block.number;
        _mint(recipient, ++tokenNumber);
        string[] memory validCategoryTags = filterValidCategories(tokenNumber, categoryTags);
        
        Post memory post = Post({
            minter: msg.sender,
            tokenID: tokenNumber,
            content: content,
            imageHashes: imageHashes,
            categories: validCategoryTags,
            imageLink: imageLink,
            isURL: urlBool,
            urlContent: urlContent,
            blockHeight: blockHeight
        });

        posts[tokenNumber] = post;
        mintedTokens[recipient].push(tokenNumber);

    }

    function tokenURI(uint tokenID) public view override returns (string memory) {
        require(_exists(tokenID), "ERC721Metadata: URI query for nonexistent token");

        Post memory currentPost = posts[tokenID];
        string memory categoryString = stringify(currentPost.categories);
        string memory imageHashString = stringify(currentPost.imageHashes);
        // Create JSON for OpenSea
        return string(abi.encodePacked(
            "data:application/json;base64,", Base64.encode(abi.encodePacked(
                "{",
                    "'minter': '", Strings.toHexString(uint160(currentPost.minter), 20), "',",
                    "'content': '", currentPost.content, "',",
                    "'imageHashes': '", imageHashString, "',",
                    "'image': '", currentPost.imageLink, "',",
                    "'categories': '", categoryString, "',",
                    "'isURL': '", Strings.toString(toUInt256(currentPost.isURL)), "',",
                    "'urlContent': '", currentPost.urlContent, "',",
                    "'blockHeight': '", Strings.toString(currentPost.blockHeight),
                "'}"
            ))
        ));
    }

    function addCategories(string[] calldata newCategories) external override{
        for (uint i = 0; i < newCategories.length; i++) {
            categories[newCategories[i]] = true;
            activeCategories.push(newCategories[i]);
        }
    }

    function removeCategories(string[] memory oldCategories) external override {
        require(hasRole(ADMIN_ROLE, msg.sender), "admin-only");
        string[] memory categoryCopy = activeCategories;
        delete activeCategories;
        for (uint i = 0; i < categoryCopy.length; i++) {
            for (uint j = 0; j < oldCategories.length; j++) {
                if(keccak256(abi.encodePacked(categoryCopy[i])) == keccak256(abi.encodePacked(oldCategories[j]))) {
                    categories[categoryCopy[i]] = false;
                    break;
                } else if (j == oldCategories.length - 1) {
                    activeCategories.push(categoryCopy[i]);
                }
            }
        }
    }

    function addCategoriesToPost(uint tokenID, string[] calldata newCategories) external override{
        require(hasRole(ADMIN_ROLE, msg.sender), "admin-only");
        for (uint i = 0; i < newCategories.length; i++) {
            if(categories[newCategories[i]] && !postCategories[tokenID][newCategories[i]]) {
                postCategories[tokenID][newCategories[i]] = true;
                posts[tokenID].categories.push(newCategories[i]);
            }
        }
    }

    function getActiveCategories() public view returns (string[] memory) {
        return activeCategories;
    }

    function resetCategoriesForPost(uint tokenID, string[] calldata newCategories) external override {
        require(hasRole(ADMIN_ROLE, msg.sender), "admin-only");
        for (uint i = 0; i < posts[tokenID].categories.length; i++) {
            postCategories[tokenID][posts[tokenID].categories[i]] = false;
        }
        delete posts[tokenID].categories;
        for (uint i = 0; i < newCategories.length; i++) {
            if(categories[newCategories[i]]) {
                postCategories[tokenID][newCategories[i]] = true;
                posts[tokenID].categories.push(newCategories[i]);
            }
        }
    }

    function updateImageHashes(uint tokenID, string[] memory imageHashes) external override {
         require(hasRole(ADMIN_ROLE, msg.sender), "admin-only");
        posts[tokenID].imageHashes = imageHashes;
    }

    function updateImage(uint tokenID, string calldata imageLink) external override {
        require(msg.sender == ownerOf(tokenID) || hasRole(ADMIN_ROLE, msg.sender), "only-token-owner-or-admin");
        posts[tokenID].imageLink = imageLink;
    }

    function updateURLContent(uint tokenID, string calldata urlContent) external override {
        require(hasRole(ADMIN_ROLE, msg.sender), "admin-only");
        require(posts[tokenID].isURL, "post-is-not-a-url");
        posts[tokenID].urlContent = urlContent;
    }

    function getPost(uint tokenID) external view override returns (Post memory post) {
        require(_exists(tokenID), "nonexistent token");
        return posts[tokenID];
    }

    function getUsersPosts(address user) external view override returns (uint[] memory) {
        return mintedTokens[user];
    }

    function isURL(uint tokenID) external view override returns (bool) {
        return posts[tokenID].isURL;
    }

    function stringify(string[] memory arr) internal pure returns(string memory) {
        string memory str = "[";
        for (uint i = 0; i < arr.length; i++) {
            if (i == 0) {
                str = string(abi.encodePacked(str, arr[i]));
            }
            else {
                str = string(abi.encodePacked(str, ", ", arr[i]));
            }
        }
        return string(abi.encodePacked(str, "]"));
    }
    
    function filterValidCategories(uint tokenID, string[] memory categoryTags) internal returns(string[] memory) {
        uint validCategoryTagsLength;
        for (uint i = 0; i < categoryTags.length; i++) {
            if (categories[categoryTags[i]]) {
                validCategoryTagsLength++;
                postCategories[tokenID][categoryTags[i]] = true;
            } else {
                delete categoryTags[i];
            }
        }
        string[] memory validCategoryTags = new string[](validCategoryTagsLength);
        uint validIndex;
        for (uint i; i < categoryTags.length; i++) {
            if (categories[categoryTags[i]]) {
                validCategoryTags[validIndex] = categoryTags[i];
                validIndex++;
            }
        }
        return validCategoryTags;
    }

    function totalSupply() public view returns (uint) {
        return tokenNumber;
    }

    function toUInt256(bool x) internal pure returns (uint r) {
        assembly { r := x }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

}