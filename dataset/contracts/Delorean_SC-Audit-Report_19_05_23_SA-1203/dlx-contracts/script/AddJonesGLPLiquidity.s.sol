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

contract AddJonesGLPLiquidity is BaseScript {
    using stdJson for string;

    function setUp() public {
        init();
    }

    function send10(address payable who) public payable {
        pk = vm.envUint("LOCALHOST_PRIVATE_KEY");
        vm.startBroadcast(pk);
        who.transfer(10 ether);
        vm.stopBroadcast();
    }

    function run() public {
        address dev = vm.envAddress("ARBITRUM_DEV_ADDRESS");
        if (eq(vm.envString("NETWORK"), "localhost")) {
            send10(payable(dev));
        }
        pk = vm.envUint("ARBITRUM_DEV_PRIVATE_KEY");

        vm.startBroadcast(pk);

        string memory config;
        if (eq(vm.envString("NETWORK"), "localhost")) {
            config = vm.readFile("json/config.localhost.json");
        } else {
            config = vm.readFile("json/config.arbitrum.json");
        }
        NPVSwap npvSwap = NPVSwap(vm.parseJsonAddress(config, ".jglp_npvSwap.address"));
        UniswapV3LiquidityPool pool = UniswapV3LiquidityPool(vm.parseJsonAddress(config, ".jglp_pool.address"));

        uint256 before = IUniswapV3Pool(pool.pool()).liquidity();
        console.log("Liquidity before:", before);

        /* addLiquidity(npvSwap, dev, 1e15, 1e15, 1e18, -180, -60); */
        addLiquidity(npvSwap, dev, 1e15, 1e15, 1e18, -360, -60);
        /* addLiquidity(npvSwap, dev, 1e15, 1e15, 1e18, -6960, -60); */

        uint256 afterVal = IUniswapV3Pool(pool.pool()).liquidity();
        console.log("Liquidity after: ", afterVal);
        console.log("Delta:           ", afterVal - before);

        // Sanity check that liquidity is set up correctly
        uint256 m = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
        if (address(npvSwap.npvToken()) < address(npvSwap.slice().yieldToken())) {
            npvSwap.previewSwapNPVForYield(m, 75162434512514376853788557312);
        } else {
            npvSwap.previewSwapNPVForYield(m, 83513816125015982100736638976);
        }

        vm.stopBroadcast();
    }
}
