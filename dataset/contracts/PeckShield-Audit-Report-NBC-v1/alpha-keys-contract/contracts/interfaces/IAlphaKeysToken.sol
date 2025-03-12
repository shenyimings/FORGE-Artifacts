// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {TokenTypes} from "../libraries/TokenTypes.sol";

interface IAlphaKeysToken {
    //
    event Trade(
        address trader,
        address player,
        bool isBuy,
        uint256 shareAmount,
        uint256 tcAmount,
        uint256 protocolFeeAmount,
        uint256 playerFeeAmount,
        uint256 supply
    );

    event TradeV2(
        address trader,
        address player,
        bool isBuy,
        uint256 shareAmount,
        uint256 tcAmount,
        uint256 protocolFeeAmount,
        uint256 playerFeeAmount,
        uint256 supply
    );

    event TradeV3(
        address trader,
        address player,
        bool isBuy,
        uint256 shareAmount,
        uint256 btcAmount,
        uint256 protocolBtcFeeAmount,
        uint256 playerBtcFeeAmount,
        uint256 supply
    );

    event TradeV4(
        address trader,
        address player,
        bool isBuy,
        uint256 shareAmount,
        uint256 btcAmount,
        uint256 protocolBtcFeeAmount,
        uint256 playerBtcFeeAmount,
        uint256 supply,
        TokenTypes.OrderType orderType,
        bytes32 orderId
    );

    event PlayerUpdated(address indexed oldPlayer, address indexed newPlayer);

    event BTCMigrated(uint256 amountTC, uint256 amountBTC);

    event LockedTs(
        address user,
        uint256 amount,
        uint256 duationTs,
        uint256 expiredTs
    );

    event PlayerFeeRatioUpdated(uint24 playerFeeRatio);

    //
    function initialize(
        address factory,
        address manager,
        string calldata name,
        string calldata symbol
    ) external;

    function getPlayer() external view returns (address);

    function getProtocolFeeRatio() external view returns (uint24);

    function getPlayerFeeRatio() external view returns (uint24);

    function getBuyPriceAfterFeeV2(
        uint256 amountX18
    ) external view returns (uint256);

    function getBuyPriceV2(uint256 amountX18) external view returns (uint256);

    function getSellPriceAfterFeeV2(
        uint256 amountX18
    ) external view returns (uint256);

    function updateNewPlayer(address newPlayer) external;

    function permitBuyKeysForV2(
        address from,
        uint256 amountX18,
        address recipient,
        TokenTypes.OrderType orderType
    ) external;

    function permitSellKeysForV2(
        address from,
        uint256 amountX18,
        address recipient,
        TokenTypes.OrderType orderType
    ) external;

    function permitLock30D(address user, uint256 amount) external;

    function getTradeOrder(
        bytes32 tradeId
    ) external view returns (TokenTypes.TradeOrder memory);
}
