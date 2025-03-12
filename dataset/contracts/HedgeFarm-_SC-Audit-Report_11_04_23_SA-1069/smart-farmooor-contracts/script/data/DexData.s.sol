pragma solidity ^0.8.0;

import "./CommonData.s.sol";

contract DexData is CommonData {
    address[] public DEX_WAVAX_USDC_ROUTE = [WAVAX, USDC];
    address[] public DEX_STG_USDC_ROUTE = [STG, USDC];
    address[] public DEX_QI_USDC_ROUTE = [QI, WAVAX, USDC];
    address[] public DEX_JOE_USDC_ROUTE = [JOE, USDC];
    address[] public DEX_WAVAX_USDT_ROUTE = [WAVAX, USDT];
    address[] public DEX_STG_USDT_ROUTE = [STG, USDC, WAVAX, USDT];
    address[] public DEX_QI_USDT_ROUTE = [QI, WAVAX, USDT];
    address[] public DEX_JOE_USDT_ROUTE = [JOE, WAVAX, USDT];
    address[] public DEX_WAVAX_SAVAX_ROUTE = [WAVAX, SAVAX];
    address[] public DEX_QI_SAVAX_ROUTE = [QI, WAVAX, SAVAX];
    address[] public DEX_WAVAX_BTCB_ROUTE = [WAVAX, BTCB];
    address[] public DEX_QI_BTCB_ROUTE = [QI, WAVAX, BTCB];
    address[] public DEX_JOE_BTCB_ROUTE = [JOE, WAVAX, BTCB];
    address[] public DEX_QI_WAVAX = [QI, WAVAX];
    address[] public DEX_JOE_WAVAX = [JOE, WAVAX];

    address[][] public routes = [
    DEX_WAVAX_USDC_ROUTE,
    DEX_STG_USDC_ROUTE,
    DEX_QI_USDC_ROUTE,
    DEX_JOE_USDC_ROUTE,
    DEX_WAVAX_USDT_ROUTE,
    DEX_STG_USDT_ROUTE,
    DEX_QI_USDT_ROUTE,
    DEX_JOE_USDT_ROUTE,
    DEX_WAVAX_SAVAX_ROUTE,
    DEX_QI_SAVAX_ROUTE,
    DEX_WAVAX_BTCB_ROUTE,
    DEX_QI_BTCB_ROUTE,
    DEX_JOE_BTCB_ROUTE,
    DEX_QI_WAVAX,
    DEX_JOE_WAVAX
    ];
}
