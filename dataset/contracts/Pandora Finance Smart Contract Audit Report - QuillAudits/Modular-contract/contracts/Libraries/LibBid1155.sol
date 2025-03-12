// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

library LibBid1155 {
    struct BidOrder {
        uint256 saleId;
        uint256 numberOfTokens;
        address sellerAddress;
        address buyerAddress;
        uint256 price;
        bool withdrawn;
    }

}