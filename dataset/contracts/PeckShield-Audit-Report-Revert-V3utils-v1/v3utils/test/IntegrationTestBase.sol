// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/V3Utils.sol";

abstract contract IntegrationTestBase is Test {
    
    uint256 constant Q64 = 2**64;

    int24 constant MIN_TICK_100 = -887272;
    int24 constant MIN_TICK_500 = -887270;

    IERC20 constant WETH_ERC20 = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    address constant WHALE_ACCOUNT = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    address FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    INonfungiblePositionManager constant NPM = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address EX0x = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF; // 0x exchange proxy


    // DAI/USDC 0.05% - one sided only DAI - current tick is near -276326 - no liquidity (-276320/-276310)
    uint256 constant TEST_NFT = 24181;
    address constant TEST_NFT_ACCOUNT = 0x8cadb20A4811f363Dadb863A190708bEd26245F8;
    address constant TEST_NFT_POOL = 0x6c6Bc977E13Df9b0de53b251522280BB72383700;

   
    uint256 constant TEST_NFT_2 = 7;  // DAI/WETH 0.3% - one sided only WETH - with liquidity and fees (-84120/-78240)
    uint256 constant TEST_NFT_2_A = 126; // DAI/USDC 0.05% - in range (-276330/-276320)
    uint256 constant TEST_NFT_2_B = 37; // USDC/WETH 0.3% - out of range (192180/193380)
    address constant TEST_NFT_2_ACCOUNT = 0x3b8ccaa89FcD432f1334D35b10fF8547001Ce3e5;
    address constant TEST_NFT_2_POOL = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;

    // DAI/USDC 0.05% - in range - with liquidity and fees
    uint256 constant TEST_NFT_3 = 4660; 
    address constant TEST_NFT_3_ACCOUNT = 0xa3eF006a7da5BcD1144d8BB86EfF1734f46A0c1E;
    address constant TEST_NFT_3_POOL = 0x6c6Bc977E13Df9b0de53b251522280BB72383700;

    // USDC/WETH 0.3% - in range - with liquidity and fees
    uint constant TEST_NFT_4 = 827;
    address constant TEST_NFT_4_ACCOUNT = 0x96653b13bD00842Eb8Bc77dCCFd48075178733ce;
    address constant TEST_NFT_4_POOL = 0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8;

    // DAI/USDC 0.05% - in range - with liquidity and fees
    uint constant TEST_NFT_5 = 23901;
    address constant TEST_NFT_5_ACCOUNT = 0x082d3e0f04664b65127876e9A05e2183451c792a;


    address constant TEST_FEE_ACCOUNT = 0x8df57E3D9dDde355dCE1adb19eBCe93419ffa0FB;

    uint256 mainnetFork;

    V3Utils v3utils;

    function _setupBase() internal {

        mainnetFork = vm.createFork("https://rpc.ankr.com/eth", 15489169);
        vm.selectFork(mainnetFork);

        v3utils = new V3Utils(NPM, EX0x);
    }  
}