//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IdeamarketPosts.sol";
import "./interfaces/INFTOpinionBase.sol";


/**
 * @title CitationMultiAction
 * @author Kelton Madden
 *
 * @dev posts and write opinion in one tx
 */

contract CitationMultiAction {
    IdeamarketPosts _postsSupply;
    address _posts;
    address _nftOpinionBase;

    constructor(address posts, address nftOpinionBase) {
        _postsSupply = IdeamarketPosts(posts);
        _posts = posts;
        _nftOpinionBase = nftOpinionBase;
    }

    function postAndCite(string calldata content, uint8 rating, string[] memory categoryTags, bool urlBool, 
        string calldata web2Content, address recipient, uint tokenID) external returns(bool) {
            string[] memory imageHashes = new string[](0);
            (bool success,) = _posts.delegatecall(abi.encodeWithSignature("mint(string,string[],string[],string,bool,string,address)", content, imageHashes, categoryTags, "", urlBool, web2Content, recipient));
            if (!success) { return false;}
            bool b = false;
            if (rating > 50) {
                b = true;
            }
            uint[] memory citations = new uint[](1);
            citations[0] =  _postsSupply.totalSupply();
            bool[] memory boolArr = new bool[](1);
            boolArr[0] =  b;
            (bool successOpinion,) =_nftOpinionBase.delegatecall(abi.encodeWithSignature("writeOpinion(uint,uint8,uint[],bool[])", tokenID, rating, citations, boolArr));
            return successOpinion;
    }
}