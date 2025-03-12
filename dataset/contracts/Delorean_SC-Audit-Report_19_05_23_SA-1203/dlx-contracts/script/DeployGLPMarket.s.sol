// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import { BaseScript } from "./BaseScript.sol";

import { UniswapV3LiquidityPool } from "../src/liquidity/UniswapV3LiquidityPool.sol";
import { IUniswapV3Pool } from "../src/interfaces/uniswap/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "../src/interfaces/uniswap/INonfungiblePositionManager.sol";
import { IUniswapV3Factory } from "../src/interfaces/uniswap/IUniswapV3Factory.sol";
import { StakedGLPYieldSource } from "../src/sources/StakedGLPYieldSource.sol";
import { YieldSlice } from "../src/core/YieldSlice.sol";
import { NPVToken } from "../src/tokens/NPVToken.sol";
import { NPVSwap } from "../src/core/NPVSwap.sol";
import { Discounter } from "../src/data/Discounter.sol";
import { YieldData } from "../src/data/YieldData.sol";

contract DeployGLPMarket is BaseScript {
    using stdJson for string;

    function setUp() public {
        init();
    }

    function run() public {
        vm.startBroadcast(pk);

        StakedGLPYieldSource source = new StakedGLPYieldSource(address(stakedGLP),
                                                               arbitrumWeth,
                                                               address(tracker));

        address yieldToken = address(source.yieldToken());

        dataDebt = new YieldData(7 days);
        dataCredit = new YieldData(7 days);

        string memory historical = vm.readFile("json/historical.json");
        uint256 daily = vm.parseJsonUint(historical, ".glp.avgDailyRewardPerToken");
        discounter = new Discounter(daily,
                                    250,
                                    10,
                                    18,
                                    1 days);

        slice = new YieldSlice("npvETH-GLP",
                               address(source),
                               address(dataDebt),
                               address(dataCredit),
                               address(discounter),
                               1e9);

        source.setOwner(address(slice));
        dataDebt.setWriter(address(slice));
        dataCredit.setWriter(address(slice));
        address npvToken = address(slice.npvToken());

        {
            uint160 initialPrice;
            address token0;
            address token1;

            // Initial price is 0.99 ETH/npvETH
            if (npvToken < yieldToken) {
                initialPrice = 78831026366734653132768280576;
                (token0, token1) = (npvToken, yieldToken);
            } else {
                initialPrice = 79627299360338034355936952320;
                (token0, token1) = (yieldToken, npvToken);
            }

            manager = INonfungiblePositionManager(arbitrumNonfungiblePositionManager);
            uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(arbitrumUniswapV3Factory).getPool(token0, token1, 3000));
            if (address(uniswapV3Pool) == address(0)) {
                uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(arbitrumUniswapV3Factory).createPool(token0, token1, 3000));
                IUniswapV3Pool(uniswapV3Pool).initialize(initialPrice);
            }
            pool = new UniswapV3LiquidityPool(address(uniswapV3Pool), arbitrumSwapRouter, arbitrumQuoterV2);
        }
        
        npvSwap = new NPVSwap(address(slice), address(pool));

        vm.stopBroadcast();

        {
            string memory objName = "deploy_glp";
            string memory json;
            json = vm.serializeAddress(objName, "address_dataCredit", address(dataCredit));
            json = vm.serializeAddress(objName, "address_dataDebt", address(dataDebt));
            json = vm.serializeAddress(objName, "address_discounter", address(discounter));
            json = vm.serializeAddress(objName, "address_npvSwap", address(npvSwap));
            json = vm.serializeAddress(objName, "address_npvToken", address(npvToken));
            json = vm.serializeAddress(objName, "address_pool", address(pool));
            json = vm.serializeAddress(objName, "address_slice", address(slice));
            json = vm.serializeAddress(objName, "address_yieldSource", address(source));

            json = vm.serializeString(objName, "contractName_dataCredit", "YieldData");
            json = vm.serializeString(objName, "contractName_dataDebt", "YieldData");
            json = vm.serializeString(objName, "contractName_discounter", "Discounter");
            json = vm.serializeString(objName, "contractName_npvSwap", "NPVSwap");
            json = vm.serializeString(objName, "contractName_npvToken", "NPVToken");
            json = vm.serializeString(objName, "contractName_pool", "UniswapV3LiquidityPool");
            json = vm.serializeString(objName, "contractName_slice", "YieldSlice");
            json = vm.serializeString(objName, "contractName_yieldSource", "IYieldSource");

            if (eq(vm.envString("NETWORK"), "arbitrum")) {
                vm.writeJson(json, "./json/deploy_glp.arbitrum.json");
            } else {
                vm.writeJson(json, "./json/deploy_glp.localhost.json");
            }
        }
    }
}
