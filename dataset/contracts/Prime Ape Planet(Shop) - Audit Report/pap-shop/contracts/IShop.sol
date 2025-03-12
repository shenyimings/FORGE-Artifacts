//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IShop {
    struct Item {
        uint256 price;
        uint256 totalQuantity;
        uint256 maxPerUser;
        uint256 sold;
        bool active;
    }

    struct ActiveItem {
        uint256 scSaleId;
        uint256 price;
        uint256 totalQuantity;
        uint256 maxPerUser;
        uint256 sold;
    }

    event Order(
        address indexed user,
        uint256 indexed scSaleId,
        uint256 price,
        uint256 timestamp
    );

    event ItemChanged(
        uint256 indexed scSaleId,
        uint256 price,
        uint256 totalQuantity,
        uint256 maxPerUser,
        bool active
    );
}
