// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

contract Config {
  // Chain's
  uint256 public constant ETH_MAINNET = 1;
  uint256 public constant POW_ETH_MAINNET = 10001;

  // ERC20's
  address public constant DAI_ADDRESS =
    0x6B175474E89094C44Da98b954EedeAC495271d0F;
  address public constant USDC_ADDRESS =
    0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant WETH9_ADDRESS =
    0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant USDT_ADDRESS =
    0xdAC17F958D2ee523a2206206994597C13D831ec7;

  // SUSHI LP
  address public constant SUSHI_SWAP_ROUTER =
    0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
  address public constant USDC_ETH_SUSHI_LP_ADDRESS =
    0x397FF1542f962076d0BFE58eA045FfA2d347ACa0;
  address public constant USDT_ETH_SUSHI_LP_ADDRESS =
    0x06da0fd433C1A5d7a4faa01111c044910A184553;

  // Uniswap's
  address public constant UNISWAP_V2_FACTORY =
    0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address public constant UNISWAP_V2_ROUTER_02 =
    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public constant UNISWAP_V3_FACTORY_ADDRESS =
    0x1F98431c8aD98523631AE4a59f267346ea31F984;
  address public constant UNISWAP_V3_SWAP_ROUTER_02 =
    0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

  // Random USDC Whale Address
  address public constant USDC_PHILANTHROPIST =
    0x8894E0a0c962CB723c1976a4421c95949bE2D4E3;
  address public constant USDT_PHILANTHROPIST =
    0x1Dc71767A191f8869646609997D98507E0768A34;
  address public constant DAI_PHILANTHROPIST =
    0x9A315BdF513367C0377FB36545857d12e85813Ef;
}
