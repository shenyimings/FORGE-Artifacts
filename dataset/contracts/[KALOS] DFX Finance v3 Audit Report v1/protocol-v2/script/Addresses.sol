// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Polygon {
    address public constant MULTISIG = 0x80D27bfb638F4Fea1e862f1bd07DEa577CB77D38;
    
    // Tokens
    address public constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public constant CADC = 0x9de41aFF9f55219D5bf4359F167d1D0c772A396D;
    address public constant EURS = 0xE111178A87A3BFf0c8d18DECBa5798827539Ae99;
    address public constant XSGD = 0xDC3326e71D45186F113a2F448984CA0e8D201995;
    address public constant NZDS = 0xeaFE31Cd9e8E01C8f0073A2C974f728Fb80e9DcE;
    address public constant TRYB = 0x4Fb71290Ac171E1d144F7221D882BECAc7196EB5;

    // Token Decimals
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant CADC_DECIMALS = 18;
    uint256 public constant EURS_DECIMALS = 2;
    uint256 public constant XSGD_DECIMALS = 6;
    uint256 public constant NZDS_DECIMALS = 6;
    uint256 public constant TRYB_DECIMALS = 6;

    // Oracles
    address public constant CHAINLINK_USDC_USD = 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7;
    address public constant CHAINLINK_CAD_USD = 0xACA44ABb8B04D07D883202F99FA5E3c53ed57Fb5;
    address public constant CHAINLINK_EUR_USD = 0x73366Fe0AA0Ded304479862808e02506FE556a98;
    address public constant CHAINLINK_SGD_USD = 0x8CE3cAc0E6635ce04783709ca3CC4F5fc5304299;
    address public constant CHAINLINK_NZD_USD = 0xa302a0B8a499fD0f00449df0a490DedE21105955;
    address public constant CHAINLINK_TRY_USD = 0xd78325DcA0F90F0FFe53cCeA1B02Bb12E1bf8FdB;

    // Epsilon (Pool Fee)
    uint256 public constant CADC_EPSILON = 5e14; // (0.05%)
    uint256 public constant EURS_EPSILON = 5e14; // (0.05%)
    uint256 public constant XSGD_EPSILON = 1e15; // (0.10%)
    uint256 public constant NZDS_EPSILON = 3e15; // (0.30%)
    uint256 public constant TRYB_EPSILON = 3e15; // (0.30%)
}

library Mainnet {
    address public constant MULTISIG = 0x27E843260c71443b4CC8cB6bF226C3f77b9695AF;

    // Tokens
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant CADC = 0xcaDC0acd4B445166f12d2C07EAc6E2544FbE2Eef;
    address public constant EUROC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address public constant XSGD = 0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96;
    address public constant NZDS = 0xDa446fAd08277B4D2591536F204E018f32B6831c;
    address public constant TRYB = 0x2C537E5624e4af88A7ae4060C022609376C8D0EB;
    address public constant GYEN = 0xC08512927D12348F6620a698105e1BAac6EcD911;
    address public constant XIDR = 0xebF2096E01455108bAdCbAF86cE30b6e5A72aa52;

    // Token Decimals
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant CADC_DECIMALS = 18;
    uint256 public constant EUROC_DECIMALS = 6;
    uint256 public constant XSGD_DECIMALS = 6;
    uint256 public constant NZDS_DECIMALS = 6;
    uint256 public constant TRYB_DECIMALS = 6;
    uint256 public constant GYEN_DECIMALS = 6;
    uint256 public constant XIDR_DECIMALS = 6;

    // Oracles
    address public constant CHAINLINK_USDC_USD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address public constant CHAINLINK_CAD_USD = 0xa34317DB73e77d453b1B8d04550c44D10e981C8e;
    address public constant CHAINLINK_EUR_USD = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    address public constant CHAINLINK_SGD_USD = 0xe25277fF4bbF9081C75Ab0EB13B4A13a721f3E13;
    address public constant CHAINLINK_NZD_USD = 0x3977CFc9e4f29C184D4675f4EB8e0013236e5f3e;
    address public constant CHAINLINK_TRY_USD = 0xB09fC5fD3f11Cf9eb5E1C5Dba43114e3C9f477b5;
    address public constant CHAINLINK_YEN_USD = 0xBcE206caE7f0ec07b545EddE332A47C2F75bbeb3;
    address public constant CHAINLINK_IDR_USD = 0x91b99C9b75aF469a71eE1AB528e8da994A5D7030;

    // Epsilon (Pool Fee)
    uint256 public constant CADC_EPSILON = 15e14; // (0.15%)
    uint256 public constant EUROC_EPSILON = 15e14; // (0.15%)
    uint256 public constant XSGD_EPSILON = 15e14; // (0.15%)
    uint256 public constant NZDS_EPSILON = 3e15; // (0.30%)
    uint256 public constant TRYB_EPSILON = 5e15; // (0.50%)
    uint256 public constant GYEN_EPSILON = 15e14; // (0.15%)
    uint256 public constant XIDR_EPSILON = 5e15; // (0.50%)
}
