// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

library LibMeta1155 {

    struct TokenMeta {
        address collectionAddress;
        uint256 tokenId;
        uint256 numberOfTokens;
        uint256 price;
        bool directSale;
        bool bidSale;
        bool status;
        address currentOwner;
    }

    function transfer(TokenMeta storage token, uint256 _numberOfTokens ) internal{
        token.numberOfTokens = token.numberOfTokens - _numberOfTokens;
        if(token.numberOfTokens == 0) {
        token.status = false;
        token.directSale = false ;
        token.bidSale = false ;
        }
    } 
}