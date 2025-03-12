// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {IAlphaKeysFactoryImpl} from "./IAlphaKeysFactoryImpl.sol";

interface IAlphaKeysFactory is IAlphaKeysFactoryImpl {
    //
    event AlphaKeysCreated(address indexed player, address indexed token);
    event AlphaKeysCreatedV2(
        address indexed player,
        address indexed token,
        uint256 indexed twitterId
    );
    event AlphaKeysCreatedForTwitter(
        address indexed player,
        address indexed token,
        uint256 indexed twitterId
    );

    event TCRequested(
        address indexed trader,
        uint256 indexed nonce,
        uint256 amountBTC,
        uint256 amountTC
    );

    event ThreeThreeRequested(
        bytes32 indexed orderId,
        address indexed tokenA,
        address ownerA,
        address indexed tokenB,
        address ownerB,
        uint256 amount,
        uint256 buyPriceBAfterFeeMax
    );

    event ThreeThreeTrade(
        bytes32 indexed orderId,
        address indexed tokenA,
        address ownerA,
        address indexed tokenB,
        address ownerB,
        uint256 amount
    );

    event ThreeThreeTradeBTC(
        bytes32 indexed orderId,
        address indexed tokenA,
        address ownerA,
        address indexed tokenB,
        address ownerB,
        uint256 amountA,
        uint256 amountB
    );

    event ThreeThreeCancelled(
        bytes32 indexed orderId,
        address indexed tokenA,
        address ownerA
    );

    event ThreeThreeRejected(
        bytes32 indexed orderId,
        address indexed tokenB,
        address ownerB
    );

    event LimitOrderCreated(
        uint256 indexed nonce,
        address indexed trader,
        address indexed token,
        bool isBuy,
        uint256 amount,
        uint256 triggerPrice,
        uint256 buyPriceAfterFeeMax
    );

    event LimitOrderFilled(
        uint256 indexed nonce,
        address indexed trader,
        address indexed token,
        bool isBuy,
        uint256 amount
    );

    event LimitOrderCancelled(uint256 indexed nonce, address indexed trader);

    event WatchlistUpdated(
        uint256 indexed twitterId,
        uint256 indexed watchTwitterId,
        bool enabled,
        uint256 amountMax,
        uint256 buyPriceMax,
        uint256 validAt
    );

    event WatchlistCopyTrade(
        uint256 indexed twitterId,
        uint256 indexed watchTwitterId,
        address token,
        uint256 amount,
        bytes32 orderId
    );

    //
    function getBTC() external view returns (address);

    function getVault() external view returns (address);

    function getProtocolFeeRatio() external view returns (uint24);

    function getPlayerFeeRatio() external view returns (uint24);

    function getProtocolFeeDestination() external view returns (address);

    function requestFund(address token, address from, uint256 amount) external;

    function requestRefund(address token, address to, uint256 amount) external;
}
