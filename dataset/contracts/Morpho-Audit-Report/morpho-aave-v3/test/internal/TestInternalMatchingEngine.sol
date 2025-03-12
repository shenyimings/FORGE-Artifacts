// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MatchingEngine} from "src/MatchingEngine.sol";

import {MarketLib} from "src/libraries/MarketLib.sol";
import {MarketBalanceLib} from "src/libraries/MarketBalanceLib.sol";

import {BucketDLL} from "@morpho-data-structures/BucketDLL.sol";
import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";

import "test/helpers/InternalTest.sol";

contract TestInternalMatchingEngine is InternalTest, MatchingEngine {
    using MarketLib for Types.Market;
    using MarketBalanceLib for Types.MarketBalances;
    using WadRayMath for uint256;
    using Math for uint256;

    using BucketDLL for BucketDLL.List;
    using LogarithmicBuckets for LogarithmicBuckets.Buckets;

    uint256 internal constant TOTAL_AMOUNT = 20 ether;
    uint256 internal constant USER_AMOUNT = 1 ether;

    function setUp() public virtual override {
        super.setUp();

        _market[dai].setIndexes(
            Types.Indexes256(
                Types.MarketSideIndexes256(WadRayMath.RAY, WadRayMath.RAY),
                Types.MarketSideIndexes256(WadRayMath.RAY, WadRayMath.RAY)
            )
        );
    }

    function testPromote(
        uint256 poolBalance,
        uint256 p2pBalance,
        uint256 poolIndex,
        uint256 p2pIndex,
        uint256 remaining
    ) public {
        poolBalance = bound(poolBalance, 0, type(uint96).max);
        p2pBalance = bound(p2pBalance, 0, type(uint96).max);
        poolIndex = bound(poolIndex, WadRayMath.RAY, WadRayMath.RAY * 1_000);
        p2pIndex = bound(p2pIndex, WadRayMath.RAY, WadRayMath.RAY * 1_000);
        remaining = bound(remaining, 0, type(uint96).max);

        uint256 toProcess = Math.min(poolBalance.rayMul(poolIndex), remaining);

        (uint256 newPoolBalance, uint256 newP2PBalance, uint256 newRemaining) =
            _promote(poolBalance, p2pBalance, Types.MarketSideIndexes256(poolIndex, p2pIndex), remaining);

        assertEq(newPoolBalance, poolBalance - toProcess.rayDiv(poolIndex));
        assertEq(newP2PBalance, p2pBalance + toProcess.rayDiv(p2pIndex));
        assertEq(newRemaining, remaining - toProcess);
    }

    function testDemote(uint256 poolBalance, uint256 p2pBalance, uint256 poolIndex, uint256 p2pIndex, uint256 remaining)
        public
    {
        poolBalance = bound(poolBalance, 0, type(uint96).max);
        p2pBalance = bound(p2pBalance, 0, type(uint96).max);
        poolIndex = bound(poolIndex, WadRayMath.RAY, WadRayMath.RAY * 1_000);
        p2pIndex = bound(p2pIndex, WadRayMath.RAY, WadRayMath.RAY * 1_000);
        remaining = bound(remaining, 0, type(uint96).max);

        uint256 toProcess = Math.min(p2pBalance.rayMul(p2pIndex), remaining);

        (uint256 newPoolBalance, uint256 newP2PBalance, uint256 newRemaining) =
            _demote(poolBalance, p2pBalance, Types.MarketSideIndexes256(poolIndex, p2pIndex), remaining);

        assertEq(newPoolBalance, poolBalance + toProcess.rayDiv(poolIndex));
        assertEq(newP2PBalance, p2pBalance - toProcess.rayDiv(p2pIndex));
        assertEq(newRemaining, remaining - toProcess);
    }

    function testPromoteSuppliers(uint256 numSuppliers, uint256 amountToPromote, uint256 maxIterations) public {
        numSuppliers = bound(numSuppliers, 0, 10);
        amountToPromote = bound(amountToPromote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numSuppliers);

        uint256 expectedPromoted = Math.min(amountToPromote, maxIterations * USER_AMOUNT);
        uint256 expectedIterations = Math.min(expectedPromoted.divUp(USER_AMOUNT), maxIterations);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        LogarithmicBuckets.Buckets storage poolSupplierBuckets = marketBalances.poolSuppliers;
        uint256 bucketId = LogarithmicBuckets.highestSetBit(USER_AMOUNT);
        address addrToMatch;

        for (uint256 i; i < numSuppliers; i++) {
            _updateSupplierInDS(dai, vm.addr(i + 1), USER_AMOUNT, 0, true);
        }

        for (uint256 i; i < expectedIterations; i++) {
            addrToMatch = addrToMatch == address(0)
                ? poolSupplierBuckets.getMatch(amountToPromote)
                : poolSupplierBuckets.buckets[bucketId].getNext(addrToMatch);
            vm.expectEmit(true, true, true, false);
            emit Events.SupplyPositionUpdated(addrToMatch, dai, 0, 0);
        }

        (uint256 promoted, uint256 iterationsDone) = this.promoteSuppliers(dai, amountToPromote, maxIterations);

        uint256 totalP2PSupply;
        for (uint256 i; i < numSuppliers; i++) {
            address user = address(vm.addr(i + 1));
            assertApproxEqDust(
                marketBalances.scaledPoolSupplyBalance(user) + marketBalances.scaledP2PSupplyBalance(user),
                USER_AMOUNT,
                "user supply"
            );
            totalP2PSupply += marketBalances.scaledP2PSupplyBalance(user);
        }

        assertEq(promoted, expectedPromoted, "promoted");
        assertApproxEqDust(totalP2PSupply, promoted, "total supply");
        assertEq(iterationsDone, expectedIterations, "iterations");
    }

    function testPromoteBorrowers(uint256 numBorrowers, uint256 amountToPromote, uint256 maxIterations) public {
        numBorrowers = bound(numBorrowers, 0, 10);
        amountToPromote = bound(amountToPromote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numBorrowers);

        uint256 expectedPromoted = Math.min(amountToPromote, maxIterations * USER_AMOUNT);
        uint256 expectedIterations = Math.min(expectedPromoted.divUp(USER_AMOUNT), maxIterations);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        LogarithmicBuckets.Buckets storage poolBorrowerBuckets = marketBalances.poolBorrowers;
        uint256 bucketId = LogarithmicBuckets.highestSetBit(USER_AMOUNT);
        address addrToMatch;

        for (uint256 i; i < numBorrowers; i++) {
            _updateBorrowerInDS(dai, vm.addr(i + 1), USER_AMOUNT, 0, true);
        }

        for (uint256 i; i < expectedIterations; i++) {
            addrToMatch = addrToMatch == address(0)
                ? poolBorrowerBuckets.getMatch(amountToPromote)
                : poolBorrowerBuckets.buckets[bucketId].getNext(addrToMatch);
            vm.expectEmit(true, true, true, false);
            emit Events.BorrowPositionUpdated(addrToMatch, dai, 0, 0);
        }

        (uint256 promoted, uint256 iterationsDone) = this.promoteBorrowers(dai, amountToPromote, maxIterations);

        uint256 totalP2PBorrow;
        for (uint256 i; i < numBorrowers; i++) {
            address user = vm.addr(i + 1);
            assertApproxEqDust(
                marketBalances.scaledPoolBorrowBalance(user) + marketBalances.scaledP2PBorrowBalance(user),
                USER_AMOUNT,
                "user borrow"
            );
            totalP2PBorrow += marketBalances.scaledP2PBorrowBalance(user);
        }

        assertEq(promoted, expectedPromoted, "promoted");
        assertApproxEqDust(totalP2PBorrow, promoted, "total borrow");
        assertEq(iterationsDone, expectedIterations, "iterations");
    }

    function testDemoteSuppliers(uint256 numSuppliers, uint256 amountToDemote, uint256 maxIterations) public {
        numSuppliers = bound(numSuppliers, 0, 10);
        amountToDemote = bound(amountToDemote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numSuppliers);

        uint256 expectedDemoted = Math.min(amountToDemote, maxIterations * USER_AMOUNT);
        uint256 expectedIterations = Math.min(expectedDemoted.divUp(USER_AMOUNT), maxIterations);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        LogarithmicBuckets.Buckets storage p2pSupplierBuckets = marketBalances.p2pSuppliers;
        uint256 bucketId = LogarithmicBuckets.highestSetBit(USER_AMOUNT);
        address addrToMatch;

        for (uint256 i; i < numSuppliers; i++) {
            _updateSupplierInDS(dai, vm.addr(i + 1), 0, USER_AMOUNT, true);
        }

        for (uint256 i; i < expectedIterations; i++) {
            addrToMatch = addrToMatch == address(0)
                ? p2pSupplierBuckets.getMatch(amountToDemote)
                : p2pSupplierBuckets.buckets[bucketId].getNext(addrToMatch);
            vm.expectEmit(true, true, true, false);
            emit Events.SupplyPositionUpdated(addrToMatch, dai, 0, 0);
        }

        uint256 demoted = this.demoteSuppliers(dai, amountToDemote, maxIterations);

        uint256 totalP2PSupply;
        for (uint256 i; i < numSuppliers; i++) {
            address user = vm.addr(i + 1);
            assertApproxEqDust(
                marketBalances.scaledPoolSupplyBalance(user) + marketBalances.scaledP2PSupplyBalance(user),
                USER_AMOUNT,
                "user supply"
            );
            totalP2PSupply += marketBalances.scaledP2PSupplyBalance(user);
        }

        assertEq(demoted, expectedDemoted, "demoted");
        assertApproxEqDust(totalP2PSupply, USER_AMOUNT * numSuppliers - demoted, "total supply");
    }

    function testDemoteBorrowers(uint256 numBorrowers, uint256 amountToDemote, uint256 maxIterations) public {
        numBorrowers = bound(numBorrowers, 0, 10);
        amountToDemote = bound(amountToDemote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numBorrowers);

        uint256 expectedDemoted = Math.min(amountToDemote, maxIterations * USER_AMOUNT);
        uint256 expectedIterations = Math.min(expectedDemoted.divUp(USER_AMOUNT), maxIterations);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];
        LogarithmicBuckets.Buckets storage p2pBorrowerBuckets = marketBalances.p2pBorrowers;
        uint256 bucketId = LogarithmicBuckets.highestSetBit(USER_AMOUNT);
        address addrToMatch;

        for (uint256 i; i < numBorrowers; i++) {
            _updateBorrowerInDS(dai, vm.addr(i + 1), 0, USER_AMOUNT, true);
        }

        for (uint256 i; i < expectedIterations; i++) {
            addrToMatch = addrToMatch == address(0)
                ? p2pBorrowerBuckets.getMatch(amountToDemote)
                : p2pBorrowerBuckets.buckets[bucketId].getNext(addrToMatch);
            vm.expectEmit(true, true, true, false);
            emit Events.BorrowPositionUpdated(addrToMatch, dai, 0, 0);
        }

        uint256 demoted = this.demoteBorrowers(dai, amountToDemote, maxIterations);

        uint256 totalP2PBorrow;
        for (uint256 i; i < numBorrowers; i++) {
            address user = vm.addr(i + 1);
            assertApproxEqDust(
                marketBalances.scaledPoolBorrowBalance(user) + marketBalances.scaledP2PBorrowBalance(user),
                USER_AMOUNT,
                "user borrow"
            );
            totalP2PBorrow += marketBalances.scaledP2PBorrowBalance(user);
        }

        assertEq(demoted, expectedDemoted, "demoted");
        assertApproxEqDust(totalP2PBorrow, USER_AMOUNT * numBorrowers - demoted, "total borrow");
    }

    function promoteSuppliers(address underlying, uint256 amount, uint256 maxIterations)
        external
        returns (uint256, uint256)
    {
        return _promoteSuppliers(underlying, amount, maxIterations);
    }

    function promoteBorrowers(address underlying, uint256 amount, uint256 maxIterations)
        external
        returns (uint256, uint256)
    {
        return _promoteBorrowers(underlying, amount, maxIterations);
    }

    function demoteSuppliers(address underlying, uint256 amount, uint256 maxIterations) external returns (uint256) {
        return _demoteSuppliers(underlying, amount, maxIterations);
    }

    function demoteBorrowers(address underlying, uint256 amount, uint256 maxIterations) external returns (uint256) {
        return _demoteBorrowers(underlying, amount, maxIterations);
    }
}
