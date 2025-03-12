// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Types} from "src/libraries/Types.sol";
import {MarketBalanceLib} from "src/libraries/MarketBalanceLib.sol";
import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";

import {Test} from "@forge-std/Test.sol";

contract TestUnitMarketBalanceLib is Test {
    using MarketBalanceLib for Types.MarketBalances;
    using LogarithmicBuckets for LogarithmicBuckets.Buckets;

    bool internal constant IS_LIFO = true;

    Types.MarketBalances internal marketBalances;

    function testScaledPoolSupplyBalance(address user, uint96 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount != 0);
        assertEq(marketBalances.scaledPoolSupplyBalance(user), 0);

        marketBalances.poolSuppliers.update(user, amount, IS_LIFO);

        assertEq(marketBalances.scaledPoolSupplyBalance(user), amount);
    }

    function testScaledPoolBorrowBalance(address user, uint96 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount != 0);
        assertEq(marketBalances.scaledPoolBorrowBalance(user), 0);

        marketBalances.poolBorrowers.update(user, amount, IS_LIFO);

        assertEq(marketBalances.scaledPoolBorrowBalance(user), amount);
    }

    function testScaledP2PSupplyBalance(address user, uint96 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount != 0);
        assertEq(marketBalances.scaledP2PSupplyBalance(user), 0);

        marketBalances.p2pSuppliers.update(user, amount, IS_LIFO);

        assertEq(marketBalances.scaledP2PSupplyBalance(user), amount);
    }

    function testScaledP2PBorrowBalance(address user, uint96 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount != 0);
        assertEq(marketBalances.scaledP2PBorrowBalance(user), 0);

        marketBalances.p2pBorrowers.update(user, amount, IS_LIFO);

        assertEq(marketBalances.scaledP2PBorrowBalance(user), amount);
    }

    function testScaledCollateralBalance(address user, uint256 amount) public {
        marketBalances.collateral[user] = amount;

        assertEq(marketBalances.scaledCollateralBalance(user), amount);
    }
}
