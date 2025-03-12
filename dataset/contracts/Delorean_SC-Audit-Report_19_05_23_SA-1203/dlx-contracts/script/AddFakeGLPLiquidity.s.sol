// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { BaseScript } from "./BaseScript.sol";

import { FakeYieldSource } from "../test/helpers/FakeYieldSource.sol";
import { UniswapV3LiquidityPool } from "../src/liquidity/UniswapV3LiquidityPool.sol";
import { IUniswapV3Factory } from "../src/interfaces/uniswap/IUniswapV3Factory.sol";
import { INonfungiblePositionManager } from "../src/interfaces/uniswap/INonfungiblePositionManager.sol";
import { IUniswapV3Pool } from "../src/interfaces/uniswap/IUniswapV3Pool.sol";
import { NPVSwap } from "../src/core/NPVSwap.sol";

contract AddFakeGLPLiquidity is BaseScript {
    using stdJson for string;

    FakeYieldSource public source;

    function setUp() public {
        init();
    }

    function run() public {
        vm.startBroadcast(pk);

        string memory filename = "./json/config.";
        filename = string.concat(filename, vm.envString("NETWORK"));
        filename = string.concat(filename, ".json");
        string memory config = vm.readFile(filename);

        npvSwap = NPVSwap(vm.parseJsonAddress(config, ".fakeglp_npvSwap.address"));
        pool = UniswapV3LiquidityPool(vm.parseJsonAddress(config, ".fakeglp_pool.address"));
        uniswapV3Pool = IUniswapV3Pool(vm.parseJsonAddress(config, ".fakeglp_uniswapV3Pool.address"));
        source = FakeYieldSource(vm.parseJsonAddress(config, ".fakeglp_yieldSource.address"));

        uint256 yieldTokenAmount;
        uint256 generatorTokenAmount;
        uint256 yieldToLock;

        console.log("source", address(source));

        source.mintBoth(deployerAddress, 10000e18);
        yieldTokenAmount = 1000e18;
        generatorTokenAmount = 1000e18;
        yieldToLock = 1000e18;

        uint256 before = uniswapV3Pool.liquidity();
        console.log("Liquidity before:", before);

        addLiquidity(npvSwap, deployerAddress, yieldTokenAmount, generatorTokenAmount, yieldToLock,  -180, -60);
        addLiquidity(npvSwap, deployerAddress, yieldTokenAmount, generatorTokenAmount, yieldToLock,  -360, -60);
        addLiquidity(npvSwap, deployerAddress, yieldTokenAmount, generatorTokenAmount, yieldToLock,  -6960, -60);

        uint256 afterVal = uniswapV3Pool.liquidity();
        console.log("Liquidity after: ", afterVal);
        console.log("Delta:           ", afterVal - before);

        // Sanity check that liquidity is set up correctly, one of these should succeed
        uint256 m = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        if (address(npvSwap.npvToken()) < address(npvSwap.slice().yieldToken())) {
            npvSwap.previewSwapNPVForYield(m, 75162434512514376853788557312);
        } else {
            npvSwap.previewSwapNPVForYield(m, 83513816125015982100736638976);
        }

        vm.stopBroadcast();
    }
}
