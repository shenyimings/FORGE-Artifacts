// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Types} from "src/libraries/Types.sol";
import {MarketLib} from "src/libraries/MarketLib.sol";

import {Test} from "@forge-std/Test.sol";

contract TestUnitMarketLib is Test {
    using MarketLib for Types.Market;

    Types.Market internal market;

    function testIsCreated(Types.Market memory _market) public {
        market = _market;

        assertEq(market.isCreated(), market.aToken != address(0));
    }

    function testGetSupplyIndexes(Types.Market memory _market) public {
        market = _market;

        Types.MarketSideIndexes256 memory indexes = market.getSupplyIndexes();

        assertEq(market.indexes.supply.poolIndex, indexes.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.p2pIndex);
    }

    function testGetBorrowIndexes(Types.Market memory _market) public {
        market = _market;

        Types.MarketSideIndexes256 memory indexes = market.getBorrowIndexes();

        assertEq(market.indexes.borrow.poolIndex, indexes.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.p2pIndex);
    }

    function testGetIndexes(Types.Market memory _market) public {
        market = _market;

        Types.Indexes256 memory indexes = market.getIndexes();

        assertEq(market.indexes.supply.poolIndex, indexes.supply.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.supply.p2pIndex);
        assertEq(market.indexes.borrow.poolIndex, indexes.borrow.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.borrow.p2pIndex);
    }

    function testSetIndexes(Types.Indexes256 memory indexes) public {
        vm.assume(indexes.supply.poolIndex <= type(uint128).max);
        vm.assume(indexes.supply.p2pIndex <= type(uint128).max);
        vm.assume(indexes.borrow.poolIndex <= type(uint128).max);
        vm.assume(indexes.borrow.p2pIndex <= type(uint128).max);

        market.setIndexes(indexes);

        assertEq(market.indexes.supply.poolIndex, indexes.supply.poolIndex);
        assertEq(market.indexes.supply.p2pIndex, indexes.supply.p2pIndex);
        assertEq(market.indexes.borrow.poolIndex, indexes.borrow.poolIndex);
        assertEq(market.indexes.borrow.p2pIndex, indexes.borrow.p2pIndex);
    }
}
