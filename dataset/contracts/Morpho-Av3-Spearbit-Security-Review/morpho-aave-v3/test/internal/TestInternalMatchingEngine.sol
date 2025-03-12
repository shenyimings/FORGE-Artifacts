// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MatchingEngine} from "src/MatchingEngine.sol";
import {MorphoInternal} from "src/MorphoInternal.sol";
import {MorphoStorage} from "src/MorphoStorage.sol";

import {MarketLib} from "src/libraries/MarketLib.sol";
import {MarketBalanceLib} from "src/libraries/MarketBalanceLib.sol";

import "test/helpers/InternalTest.sol";

contract TestInternalMatchingEngine is InternalTest, MatchingEngine {
    using MarketLib for Types.Market;
    using MarketBalanceLib for Types.MarketBalances;
    using WadRayMath for uint256;
    using Math for uint256;

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

        Types.MarketBalances storage marketBalances = _marketBalances[dai];

        for (uint256 i; i < numSuppliers; i++) {
            _updateSupplierInDS(dai, vm.addr(i + 1), USER_AMOUNT, 0, true);
        }

        (uint256 promoted, uint256 iterationsDone) = _promoteSuppliers(dai, amountToPromote, maxIterations);

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

        uint256 expectedPromoted = Math.min(amountToPromote, maxIterations * USER_AMOUNT);
        expectedPromoted = Math.min(expectedPromoted, numSuppliers * USER_AMOUNT);

        uint256 expectedIterations = Math.min(expectedPromoted.divUp(USER_AMOUNT), maxIterations);

        assertEq(promoted, expectedPromoted, "promoted");
        assertApproxEqDust(totalP2PSupply, promoted, "total borrow");
        assertEq(iterationsDone, expectedIterations, "iterations");
    }

    function testPromoteBorrowers(uint256 numBorrowers, uint256 amountToPromote, uint256 maxIterations) public {
        numBorrowers = bound(numBorrowers, 0, 10);
        amountToPromote = bound(amountToPromote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numBorrowers);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];

        for (uint256 i; i < numBorrowers; i++) {
            _updateBorrowerInDS(dai, vm.addr(i + 1), USER_AMOUNT, 0, true);
        }

        (uint256 promoted, uint256 iterationsDone) = _promoteBorrowers(dai, amountToPromote, maxIterations);

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

        uint256 expectedPromoted = Math.min(amountToPromote, maxIterations * USER_AMOUNT);
        expectedPromoted = Math.min(expectedPromoted, numBorrowers * USER_AMOUNT);

        uint256 expectedIterations = Math.min(expectedPromoted.divUp(USER_AMOUNT), maxIterations);

        assertEq(promoted, expectedPromoted, "promoted");
        assertApproxEqDust(totalP2PBorrow, promoted, "total borrow");
        assertEq(iterationsDone, expectedIterations, "iterations");
    }

    function testDemoteSuppliers(uint256 numSuppliers, uint256 amountToDemote, uint256 maxIterations) public {
        numSuppliers = bound(numSuppliers, 0, 10);
        amountToDemote = bound(amountToDemote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numSuppliers);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];

        for (uint256 i; i < numSuppliers; i++) {
            _updateSupplierInDS(dai, vm.addr(i + 1), 0, USER_AMOUNT, true);
        }

        uint256 demoted = _demoteSuppliers(dai, amountToDemote, maxIterations);

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

        uint256 expectedDemoted = Math.min(amountToDemote, maxIterations * USER_AMOUNT);
        expectedDemoted = Math.min(expectedDemoted, numSuppliers * USER_AMOUNT);

        assertEq(demoted, expectedDemoted, "demoted");
        assertEq(totalP2PSupply, USER_AMOUNT * numSuppliers - demoted, "total borrow");
    }

    function testDemoteBorrowers(uint256 numBorrowers, uint256 amountToDemote, uint256 maxIterations) public {
        numBorrowers = bound(numBorrowers, 0, 10);
        amountToDemote = bound(amountToDemote, 0, TOTAL_AMOUNT);
        maxIterations = bound(maxIterations, 0, numBorrowers);

        Types.MarketBalances storage marketBalances = _marketBalances[dai];

        for (uint256 i; i < numBorrowers; i++) {
            _updateBorrowerInDS(dai, vm.addr(i + 1), 0, USER_AMOUNT, true);
        }

        uint256 demoted = _demoteBorrowers(dai, amountToDemote, maxIterations);

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

        uint256 expectedDemoted = Math.min(amountToDemote, maxIterations * USER_AMOUNT);
        expectedDemoted = Math.min(expectedDemoted, numBorrowers * USER_AMOUNT);

        assertEq(demoted, expectedDemoted, "demoted");
        assertEq(totalP2PBorrow, USER_AMOUNT * numBorrowers - demoted, "total borrow");
    }
}
