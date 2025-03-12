// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Test } from "@std/Test.sol";
import { AggregatorV3Interface } from "chainlink/interfaces/AggregatorV3Interface.sol";
import { console2 } from "@std/console2.sol";
import { Oracle } from "../../src/core/Oracle.sol";
import { getTS, Period } from "../shared/utils.sol";

contract OracleChainlinkTest is Test {
    address btc_usd = 0x6ce185860a4963106506C203335A2910413708e9;
    address eth_usd = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    Oracle oracle;

    function setUp() public virtual {
        console2.log(">>>Divergence Protocol Solidity Test<<<");
        vm.createSelectFork("arbitrum_ankr");
        oracle = new Oracle();
    }

    function test_chainLink() public {
        string[] memory underlyings = new string[](2);
        underlyings[0] = "BTC";
        underlyings[1] = "ETH";
        address[] memory oracles = new address[](2);
        oracles[0] = btc_usd;
        oracles[1] = eth_usd;
        oracle.setExternalOracle(underlyings, oracles);

        (uint256 start, uint256 expiries) = getTS(Period.BIWEEKLY);
        console2.log("now: %s", block.timestamp);
        (uint256 price_, uint256 actualTs) = oracle.getPriceByExternal(underlyings[0], block.timestamp - 1000);
        console2.log("price: %s, actualTs: %s", price_, actualTs);
    }
}
