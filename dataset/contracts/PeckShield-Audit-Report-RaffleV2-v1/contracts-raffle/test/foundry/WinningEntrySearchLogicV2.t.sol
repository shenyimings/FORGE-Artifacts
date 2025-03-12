// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {WinningEntrySearchLogicV2} from "../../contracts/WinningEntrySearchLogicV2.sol";
import {TestHelpers} from "./TestHelpers.sol";

contract WinningEntrySearchLogicImplementation is WinningEntrySearchLogicV2 {
    function run(
        uint256 randomWord,
        uint256 currentEntryIndex,
        uint256[] memory winningEntriesBitmap
    )
        external
        pure
        returns (
            uint256,
            uint256,
            uint256[] memory
        )
    {
        return _searchForWinningEntryUntilThereIsNotADuplicate(randomWord, currentEntryIndex, winningEntriesBitmap);
    }
}

contract WinningEntrySearchLogic_Test is TestHelpers {
    WinningEntrySearchLogicImplementation private logic;

    function setUp() public {
        logic = new WinningEntrySearchLogicImplementation();
    }

    function testFuzz_SomeParticipantsDrawnMoreThanOnce(uint256 randomWord) public {
        uint256[] memory winningEntriesBitmap = new uint256[](2);
        uint256 currentEntryIndex = 511;
        uint256 winningEntry;
        uint256 remainingEntries = (511 * 512) / 2;

        for (uint256 i; i < 512; i++) {
            (randomWord, winningEntry, winningEntriesBitmap) = logic.run(
                randomWord,
                currentEntryIndex,
                winningEntriesBitmap
            );
            remainingEntries -= winningEntry;
        }
        assertEq(winningEntriesBitmap[0], type(uint256).max);
        assertEq(winningEntriesBitmap[1], type(uint256).max);
        assertEq(remainingEntries, 0);
    }
}
