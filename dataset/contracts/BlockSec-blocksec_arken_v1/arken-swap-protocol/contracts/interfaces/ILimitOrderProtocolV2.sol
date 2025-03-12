// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library LimitOrderProtocolV2 {
    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender; 
        uint256 makingAmount;
        uint256 takingAmount;
        bytes makerAssetData;
        bytes takerAssetData;
        bytes getMakerAmount; 
        bytes getTakerAmount; 
        bytes predicate;      
        bytes permit;         
        bytes interaction;
    }
}

interface ILimitOrderProtocolV2 {
    function fillOrder(
        LimitOrderProtocolV2.Order memory order,
        bytes calldata signature,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 thresholdAmount
    ) external returns(uint256, uint256);
}