// SPDX-License-Identifier: BUSL-1.1
pragma solidity >0.7.6;

pragma experimental ABIEncoderV2;

/**
 * @title OpenLevInterface
 * @author OpenLeverage
 */
interface OpenLevInterface {
    struct Market {
        // Market info
        address pool0; // Lending Pool 0
        address pool1; // Lending Pool 1
        address token0; // Lending Token 0
        address token1; // Lending Token 1
        uint16 marginLimit; // Margin ratio limit for specific trading pair. Two decimal in percentage, ex. 15.32% => 1532
        uint16 feesRate; // feesRate 30=>0.3%
        uint16 priceDiffientRatio;
        address priceUpdater;
        uint256 pool0Insurance; // Insurance balance for token 0
        uint256 pool1Insurance; // Insurance balance for token 1
        uint32[] dexs;
    }

    struct Trade {
        // Trade storage
        uint256 deposited; // Balance of deposit token
        uint256 held; // Balance of held position
        bool depositToken; // Indicate if the deposit token is token 0 or token 1
        uint128 lastBlockNum; // Block number when the trade was touched last time, to prevent more than one operation within same block
    }

    function markets(uint16 marketId) external view returns (Market memory market);

    function activeTrades(
        address trader,
        uint16 marketId,
        bool longToken
    ) external view returns (Trade memory trade);

    function updatePrice(uint16 marketId, bytes memory dexData) external;

    function marginTradeFor(
        address trader,
        uint16 marketId,
        bool longToken,
        bool depositToken,
        uint256 deposit,
        uint256 borrow,
        uint256 minBuyAmount,
        bytes memory dexData
    ) external payable returns (uint256 newHeld);

    function closeTradeFor(
        address trader,
        uint16 marketId,
        bool longToken,
        uint256 closeHeld,
        uint256 minOrMaxAmount,
        bytes memory dexData
    ) external returns (uint256 depositReturn);
}
