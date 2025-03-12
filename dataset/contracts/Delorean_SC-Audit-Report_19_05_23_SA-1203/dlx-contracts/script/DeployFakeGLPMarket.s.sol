// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseScript } from "./BaseScript.sol";

import { IWrappedETH } from "../src/interfaces/IWrappedETH.sol";
import { FakeToken } from "../test/helpers/FakeToken.sol";
import { FakeYieldSource } from "../test/helpers/FakeYieldSource.sol";
import { FakeYieldSourceWETH } from "../test/helpers/FakeYieldSourceWETH.sol";
import { UniswapV3LiquidityPool } from "../src/liquidity/UniswapV3LiquidityPool.sol";
import { ILiquidityPool } from "../src/interfaces/ILiquidityPool.sol";
import { IUniswapV3Pool } from "../src/interfaces/uniswap/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "../src/interfaces/uniswap/INonfungiblePositionManager.sol";
import { IUniswapV3Factory } from "../src/interfaces/uniswap/IUniswapV3Factory.sol";
import { IYieldSource } from "../src/interfaces/IYieldSource.sol";
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

    function initUniswapV3Pool() public returns (address, address) {
        // Initial price is 0.99 ETH/npvETH
        uint160 initialPrice;
        address token0;
        address token1;

        if (npvToken < yieldToken) {
            initialPrice = 78831026366734653132768280576;
            (token0, token1) = (npvToken, yieldToken);
        } else {
            initialPrice = 79627299360338034355936952320;
            (token0, token1) = (yieldToken, npvToken);
        }

        manager = INonfungiblePositionManager(nonfungiblePositionManager);
        uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(uniswapV3Factory).getPool(token0, token1, 3000));
        if (address(uniswapV3Pool) == address(0)) {
            uniswapV3Pool = IUniswapV3Pool(IUniswapV3Factory(uniswapV3Factory).createPool(token0, token1, 3000));
            IUniswapV3Pool(uniswapV3Pool).initialize(initialPrice);
        }
        pool = newUniswapV3LiquidityPool(address(uniswapV3Pool));

        return (address(uniswapV3Pool), address(pool));
    }

    function run() public {
        vm.startBroadcast(pk);

        IYieldSource source;

        FakeYieldSource fakeSource = new FakeYieldSource(10000000000000);
        fakeSource.mintBoth(0x70997970C51812dc3A010C7d01b50e0d17dc79C8, 10000e18);
        fakeSource.mintBoth(deployerAddress, 10000e18);
        source = IYieldSource(fakeSource);

        yieldToken = address(source.yieldToken());
        dataDebt = new YieldData(20);
        dataCredit = new YieldData(20);
        discounter = new Discounter(1e13,
                                    500,
                                    360,
                                    18,
                                    1 days);
        slice = new YieldSlice("npvETH-fGLP",
                               address(source),
                               address(dataDebt),
                               address(dataCredit),
                               address(discounter),
                               1e9);
        npvToken = address(slice.npvToken());

        source.setOwner(address(slice));
        dataDebt.setWriter(address(slice));
        dataCredit.setWriter(address(slice));

        address uniswapV3Pool;
        address poolAddress;
        (uniswapV3Pool, poolAddress) = initUniswapV3Pool();
        pool = ILiquidityPool(poolAddress);

        npvSwap = new NPVSwap(address(slice), address(pool));

        vm.stopBroadcast();

        console.log("Slice:      ", address(slice));
        console.log("NPV token:  ", npvToken);
        console.log("NPV token:  ", address(slice.npvToken()));
        console.log("Yield token:", yieldToken);
        console.log("Gen token:  ", address(source.generatorToken()));

        {
            string memory objName = "deploy";
            string memory json;
            json = vm.serializeAddress(objName, "address_dataCredit", address(dataCredit));
            json = vm.serializeAddress(objName, "address_dataDebt", address(dataDebt));
            json = vm.serializeAddress(objName, "address_discounter", address(discounter));
            json = vm.serializeAddress(objName, "address_npvSwap", address(npvSwap));
            json = vm.serializeAddress(objName, "address_npvToken", address(npvToken));
            json = vm.serializeAddress(objName, "address_pool", address(pool));
            json = vm.serializeAddress(objName, "address_uniswapV3Pool", address(uniswapV3Pool));
            json = vm.serializeAddress(objName, "address_slice", address(slice));
            json = vm.serializeAddress(objName, "address_yieldSource", address(source));

            json = vm.serializeString(objName, "contractName_dataCredit", "YieldData");
            json = vm.serializeString(objName, "contractName_dataDebt", "YieldData");
            json = vm.serializeString(objName, "contractName_discounter", "Discounter");
            json = vm.serializeString(objName, "contractName_npvSwap", "NPVSwap");
            json = vm.serializeString(objName, "contractName_npvToken", "NPVToken");
            json = vm.serializeString(objName, "contractName_pool", "UniswapV3LiquidityPool");
            json = vm.serializeString(objName, "contractName_uniswapV3Pool", "IUniswapV3Pool");
            json = vm.serializeString(objName, "contractName_slice", "YieldSlice");
            json = vm.serializeString(objName, "contractName_yieldSource", "FakeYieldSource");

            string memory filename = "./json/deploy_fakeglp";
            filename = string.concat(filename, ".");
            filename = string.concat(filename, vm.envString("NETWORK"));
            filename = string.concat(filename, ".json");

            vm.writeJson(json, filename);
        }
    }
}
