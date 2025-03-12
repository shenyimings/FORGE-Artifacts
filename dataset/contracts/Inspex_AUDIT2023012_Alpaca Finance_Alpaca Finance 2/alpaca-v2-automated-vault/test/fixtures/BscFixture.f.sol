// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import "@forge-std/Test.sol";

// interfaces
import { IERC20 } from "src/interfaces/IERC20.sol";
import { IPancakeV3Router } from "src/interfaces/pancake-v3/IPancakeV3Router.sol";
import { IPancakeV3MasterChef } from "src/interfaces/pancake-v3/IPancakeV3MasterChef.sol";
import { IPancakeV3QuoterV2 } from "src/interfaces/pancake-v3/IPancakeV3QuoterV2.sol";
import { ICommonV3PositionManager } from "src/interfaces/ICommonV3PositionManager.sol";
import { ICommonV3Pool } from "src/interfaces/ICommonV3Pool.sol";
import { IZapV3 } from "src/interfaces/IZapV3.sol";
import { IChainlinkAggregator } from "src/interfaces/IChainlinkAggregator.sol";

contract BscFixture is Test {
  // Forks
  uint256 public constant FORK_BLOCK_NUMBER_1 = 27_515_914;

  // Tokens
  IERC20 public constant cake = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
  IERC20 public constant wbnb = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
  IERC20 public constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
  IERC20 public constant busd = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
  IERC20 public constant doge = IERC20(0xbA2aE424d960c26247Dd6c32edC70B295c744C43);

  // PancakeV3
  IPancakeV3Router public constant pancakeV3Router = IPancakeV3Router(0x13f4EA83D0bd40E75C8222255bc855a974568Dd4);
  ICommonV3PositionManager public constant pancakeV3PositionManager =
    ICommonV3PositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);
  IPancakeV3MasterChef public constant pancakeV3MasterChef =
    IPancakeV3MasterChef(0x556B9306565093C855AEA9AE92A594704c2Cd59e);
  IPancakeV3QuoterV2 public constant pancakeV3Quoter = IPancakeV3QuoterV2(0xB048Bbc1Ee6b733FFfCFb9e9CeF7375518e25997);
  // token0 = USDT, token1 = WBNB, fee = 500
  ICommonV3Pool public constant pancakeV3USDTWBNBPool = ICommonV3Pool(0x36696169C63e42cd08ce11f5deeBbCeBae652050);
  // token0 = DOGE, token1 = WBNB, fee = 2500
  ICommonV3Pool public constant pancakeV3DOGEWBNBPool = ICommonV3Pool(0xce6160bB594fC055c943F59De92ceE30b8c6B32c);
  // token0 = CAKE, token1 = USDT, fee = 2500
  ICommonV3Pool public constant pancakeV3CAKEUSDTPool = ICommonV3Pool(0x7f51c8AaA6B0599aBd16674e2b17FEc7a9f674A1);
  // token0 = USDT, token1 = BUSD, fee = 100
  ICommonV3Pool public constant pancakeV3USDTBUSD100Pool = ICommonV3Pool(0x4f3126d5DE26413AbDCF6948943FB9D0847d9818);

  // Zap
  IZapV3 public constant zapV3 = IZapV3(0xC462E9a70b16009d63fE9dFe701cA5bf70cBCb55);

  // Chainlink feeds
  IChainlinkAggregator wbnbFeed = IChainlinkAggregator(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
  IChainlinkAggregator usdtFeed = IChainlinkAggregator(0xB97Ad0E74fa7d920791E90258A6E2085088b4320);
  IChainlinkAggregator dogeFeed = IChainlinkAggregator(0x3AB0A0d137D4F946fBB19eecc6e92E64660231C8);
  IChainlinkAggregator busdFeed = IChainlinkAggregator(0xcBb98864Ef56E9042e7d2efef76141f15731B82f);

  constructor() {
    // Tokens
    vm.label(address(wbnb), "WBNB");
    vm.label(address(usdt), "USDT");
    vm.label(address(busd), "BUSD");
    vm.label(address(doge), "DOGE");

    // Pancake V3
    vm.label(address(pancakeV3Router), "pancakeV3Router");
    vm.label(address(pancakeV3PositionManager), "pancakeV3PositionManager");
    vm.label(address(pancakeV3MasterChef), "pancakeV3MasterChef");
    vm.label(address(pancakeV3Quoter), "pancakeV3Quoter");
    vm.label(address(pancakeV3USDTWBNBPool), "pancakeV3USDTWBNBPool");
    vm.label(address(pancakeV3DOGEWBNBPool), "pancakeV3DOGEWBNBPool");
    vm.label(address(pancakeV3USDTBUSD100Pool), "pancakeV3USDTBUSD100Pool");

    // Zap
    vm.label(address(zapV3), "zapV3");
  }
}
