// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {WinningEntrySearchLogic} from "../../contracts/WinningEntrySearchLogic.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract WinningEntrySearchLogicImplementation is WinningEntrySearchLogic {
    function run(
        uint256 currentEntryIndex,
        uint256 winningEntry,
        uint256[] memory winningEntriesBitmap
    ) external pure returns (uint256, uint256[] memory) {
        return _incrementWinningEntryUntilThereIsNotADuplicate(currentEntryIndex, winningEntry, winningEntriesBitmap);
    }
}

contract WinningEntrySearchLogic_Test is TestHelpers {
    WinningEntrySearchLogicImplementation private logic;

    function setUp() public {
        logic = new WinningEntrySearchLogicImplementation();
    }

    function test_SomeParticipantsDrawnMoreThanOnce() public {
        uint256[] memory winningEntriesBitmap = new uint256[](1);
        uint256 currentEntryIndex = 107;
        uint256 winningEntry;
        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 0, winningEntriesBitmap);
        assertEq(winningEntry, 0);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 1, winningEntriesBitmap);
        assertEq(winningEntry, 1);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 2, winningEntriesBitmap);
        assertEq(winningEntry, 2);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 0, winningEntriesBitmap);
        assertEq(winningEntry, 3);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 1, winningEntriesBitmap);
        assertEq(winningEntry, 4);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 2, winningEntriesBitmap);
        assertEq(winningEntry, 5);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 0, winningEntriesBitmap);
        assertEq(winningEntry, 6);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 1, winningEntriesBitmap);
        assertEq(winningEntry, 7);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 2, winningEntriesBitmap);
        assertEq(winningEntry, 8);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 5, winningEntriesBitmap);
        assertEq(winningEntry, 9);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 6, winningEntriesBitmap);
        assertEq(winningEntry, 10);
    }

    function test_SomeParticipantsDrawnMoreThanOnce_MultipleBucketsWithOverflow() public {
        uint256[] memory winningEntriesBitmap = new uint256[](2);
        uint256 currentEntryIndex = 511;
        uint256 winningEntry;

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 255, winningEntriesBitmap);
        assertEq(winningEntry, 255);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 255, winningEntriesBitmap);
        assertEq(winningEntry, 256);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 511, winningEntriesBitmap);
        assertEq(winningEntry, 511);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 511, winningEntriesBitmap);
        assertEq(winningEntry, 0);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 510, winningEntriesBitmap);
        assertEq(winningEntry, 510);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 376, winningEntriesBitmap);
        assertEq(winningEntry, 376);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 333, winningEntriesBitmap);
        assertEq(winningEntry, 333);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 45, winningEntriesBitmap);
        assertEq(winningEntry, 45);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 0, winningEntriesBitmap);
        assertEq(winningEntry, 1);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 77, winningEntriesBitmap);
        assertEq(winningEntry, 77);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 300, winningEntriesBitmap);
        assertEq(winningEntry, 300);
    }

    function test_SomeParticipantsDrawnMoreThanOnce_MultipleBucketsWithOverflow_EntriesCountNotDivisibleBy256() public {
        uint256[] memory winningEntriesBitmap = new uint256[](2);
        uint256 currentEntryIndex = 399;
        uint256 winningEntry;

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 399, winningEntriesBitmap);
        assertEq(winningEntry, 399);

        (winningEntry, winningEntriesBitmap) = logic.run(currentEntryIndex, 399, winningEntriesBitmap);
        assertEq(winningEntry, 0);
    }
}
