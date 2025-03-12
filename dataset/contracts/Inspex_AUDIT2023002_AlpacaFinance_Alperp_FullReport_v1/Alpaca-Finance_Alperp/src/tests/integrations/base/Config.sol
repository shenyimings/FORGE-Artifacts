// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

contract Config {
  address public constant ALPACA_BUSD_VAULT =
    0x7C9e73d4C71dae564d41F78d56439bB4ba87592f;
  address public constant ALPACA_WBTC_VAULT =
    0x08FC9Ba2cAc74742177e0afC3dC8Aed6961c24e7;
  address public constant ALPACA_BNB_VAULT =
    0xd7D069493685A581d27824Fc46EdA46B7EfC0063;

  address public constant BUSD_TOKEN =
    0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
  address public constant WBTC_TOKEN =
    0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;
  address public constant BNB_TOKEN =
    0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

  address public constant CHAINLINK_ORACLE =
    0x634902128543b25265da350e2d961C7ff540fC71;

  address public constant BUSD_PHILANTROPHIST =
    0x8894E0a0c962CB723c1976a4421c95949bE2D4E3;
  address public constant WBTC_PHILANTROPHIST =
    0xF977814e90dA44bFA03b6295A0616a897441aceC;
  address public constant BNB_PHILANTROPHIST =
    0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;

  address public constant BUSD_CHAINLINK_ORACLE =
    0xcBb98864Ef56E9042e7d2efef76141f15731B82f;
  address public constant WBTC_CHAINLINK_ORACLE =
    0x264990fbd0A4796A3E3d8E37C4d5F87a3aCa5Ebf;
  address public constant BNB_CHAINLINK_ORACLE =
    0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE;
}
