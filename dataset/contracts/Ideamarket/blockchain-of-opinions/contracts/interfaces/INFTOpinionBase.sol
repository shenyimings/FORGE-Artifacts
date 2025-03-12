//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title INFTOpinionBase
 * @author Kelton Madden
 */

interface INFTOpinionBase {

    struct Opinion {
        address author;
        uint tokenID;
        uint8 rating;
        uint[] citations;
        bool[] inFavorArr;
        uint blockHeight;
    }

    function writeOpinion(uint tokenID, uint8 rating, uint[] calldata citations, bool[] calldata inFavorArr) external;
    function getOpinion(uint tokenID, address user) external view returns (Opinion[] memory);
    function getUsersOpinions(address user) external view returns (Opinion[] memory);
    function getOpinionsAboutNFT(uint tokenID) external view returns (Opinion[] memory);
    function getLatestOpinionsAboutNFT(uint tokenID) external view returns (Opinion[] memory);
    function getOpinionedNFTs() external view returns (uint[] memory);
    function getAllOpinions() external view returns (Opinion[] memory);
}