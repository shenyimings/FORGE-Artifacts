// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

library LibBid {
    struct BidOrder {
        uint256 bidId;
        uint256 saleId;
        address sellerAddress;
        address buyerAddress;
        uint256 price;
        bool withdrawn;
    }

}