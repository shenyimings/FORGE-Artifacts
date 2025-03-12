// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IArkenDexV3 {
    enum RouterInterface {
        UNISWAP_V2,
        BAKERY,
        VYPER,
        VYPER_UNDERLYING,
        SADDLE,
        DODO_V2,
        DODO_V1,
        DFYN,
        BALANCER,
        UNISWAP_V3,
        CURVE_TRICRYPTO_V2,
        LIMIT_ORDER_PROTOCOL_V2,
        KYBER_DMM
    }
    struct TradeRoute {
        address routerAddress;
        address lpAddress;
        address fromToken;
        address toToken;
        address from;
        address to;
        uint32 part;
        uint8 direction; // DODO
        int16 fromTokenIndex; // Vyper
        int16 toTokenIndex; // Vyper
        uint16 amountAfterFee; // 9970 = fee 0.3% -- 10000 = no fee
        RouterInterface dexInterface; // uint8
    }
    struct TradeDescription {
        address srcToken;
        address dstToken;
        uint256 amountIn;
        uint256 amountOutMin;
        address payable to;
        TradeRoute[] routes;
        bool isRouterSource;
        bool isSourceFee;
    }
    struct TradeData {
        uint256 amountIn;
    }
    struct UniswapV3CallbackData {
        address token0;
        address token1;
        uint24 fee;
    }

    function trade(TradeDescription memory desc) external payable;

    function tradeStopLimit(
        TradeDescription memory desc,
        uint256 stopLimitFee,
        uint256 minimumStopLimitFee
    ) external payable;
}
