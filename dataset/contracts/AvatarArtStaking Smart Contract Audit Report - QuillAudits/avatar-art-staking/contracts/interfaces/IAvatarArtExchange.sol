// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAvatarArtExchange{
    /**
     * @dev Allow or disallow `token0Address` to be traded on AvatarArtOrderBook
    */
    function setPairInfo(address token0Address, address token1Address, bool tradable, uint256 minPrice, uint256 maxPrice) external returns(bool);
    
    /**
     * @dev Buy `token0Address` with `price` and `amount`
     */ 
    function buy(address token0Address, address token1Address, uint256 price, uint256 amount) external returns(bool);
    
    /**
     * @dev Sell `token0Address` with `price` and `amount`
     */ 
    function sell(address token0Address, address token1Address, uint256 price, uint256 amount) external returns(bool);
    
    /**
     * @dev Cancel an open trading order for `token0Address` by `orderId`
     */ 
    function cancel(address token0Address, address token1Address, uint256 orderId, uint256 orderType) external returns(bool);
}