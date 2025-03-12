// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

library LibMeta {

    struct TokenMeta {
        uint256 saleId;
        address collectionAddress;
        uint256 tokenId;
        uint256 price;
        bool directSale;
        bool bidSale;
        bool status;
        uint256 bidStartTime;
        uint256 bidEndTime;
        address currentOwner;
    }

   function transfer(TokenMeta storage token, address _to ) internal{
        token.currentOwner = _to;
        token.status = false;
        token.directSale = false ;
        token.bidSale = false ;

    } 
}