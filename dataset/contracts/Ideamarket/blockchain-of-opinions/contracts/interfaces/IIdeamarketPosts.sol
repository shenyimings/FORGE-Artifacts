//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IIdeamarketPosts
 * @author Kelton Madden
 */

interface IIdeamarketPosts {
    struct Post {
        address minter;
        uint tokenID;
        string content;
        string[] imageHashes;
        string[] categories;
        string imageLink;
        bool isURL;
        string urlContent; 
        uint blockHeight;
    }

    function addCategories(string[] calldata categories) external;
    function removeCategories(string[] calldata categories) external;
    function addCategoriesToPost(uint tokenID, string[] calldata category) external;
    function resetCategoriesForPost(uint tokenID, string[] calldata category) external;
    function updateURLContent(uint tokenID, string calldata urlContent) external;
    function updateImageHashes(uint tokenId, string[] calldata imagehashes) external;
    function updateImage(uint tokenID, string calldata imageLink) external;
    function getPost(uint tokenID) external view returns (Post memory post);
    function getUsersPosts(address user) external view returns (uint[] memory);
    function isURL(uint tokenID) external view returns (bool);
}
