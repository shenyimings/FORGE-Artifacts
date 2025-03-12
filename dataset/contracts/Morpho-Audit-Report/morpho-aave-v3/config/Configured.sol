// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Config, ConfigLib} from "config/ConfigLib.sol";

import {StdChains, VmSafe} from "@forge-std/StdChains.sol";

contract Configured is StdChains {
    using ConfigLib for Config;

    VmSafe private constant vm = VmSafe(address(uint160(uint256(keccak256("hevm cheat code")))));

    Config internal config;

    address internal dai;
    address internal usdc;
    address internal usdt;
    address internal aave;
    address internal link;
    address internal wbtc;
    address internal weth;
    address internal wNative;
    address internal stNative;
    address[] internal lsdNatives;
    address[] internal allUnderlyings;

    function _network() internal view virtual returns (string memory) {
        try vm.envString("NETWORK") returns (string memory configNetwork) {
            return configNetwork;
        } catch {
            return "ethereum-mainnet";
        }
    }

    function _rpcAlias() internal virtual returns (string memory) {
        return config.getRpcAlias();
    }

    function _initConfig() internal returns (Config storage) {
        if (bytes(config.json).length == 0) {
            string memory root = vm.projectRoot();
            string memory path = string.concat(root, "/config/", _network(), ".json");

            config.json = vm.readFile(path);
        }

        return config;
    }

    function _loadConfig() internal virtual {
        dai = config.getAddress("DAI");
        usdc = config.getAddress("USDC");
        usdt = config.getAddress("USDT");
        aave = config.getAddress("AAVE");
        link = config.getAddress("LINK");
        wbtc = config.getAddress("WBTC");
        weth = config.getAddress("WETH");
        wNative = config.getWrappedNative();
        lsdNatives = config.getLsdNatives();
        stNative = lsdNatives[0];

        allUnderlyings = [dai, usdc, aave, usdt, wbtc, weth];

        for (uint256 i; i < lsdNatives.length; ++i) {
            allUnderlyings.push(lsdNatives[i]);
        }
    }
}
