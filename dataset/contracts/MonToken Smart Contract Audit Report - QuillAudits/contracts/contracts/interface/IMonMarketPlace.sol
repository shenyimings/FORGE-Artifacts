// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMonMarketPlace{
     
    function cancelSellOrder(uint256 tokenId) external returns(bool);

    function createSellOrder(uint tokenId, uint price) external returns(bool);
    
    function purchase(uint tokenId) external returns(uint);
}