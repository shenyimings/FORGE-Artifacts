// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { PerformanceFeeSuggestion } from "../interfaces/IFee.sol";
import { EnumerableSetUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

struct IndexStrategyStorage {
    uint256 seqNum;
    PerformanceFeeSuggestion[] performanceFeeSuggestions;
    address feeSuggester;
    EnumerableSetUpgradeable.AddressSet feeWhitelist;
}

library IndexStrategyStorageLib {
    // keccak256("brokkr.storage.index.strategy");
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant storagePosition =
        0x2ce6004f0ad739ed89e5770ca0f6d6dc988889a26eb7822351ae8f1bc8aa5656;

    function getStorage()
        internal
        pure
        returns (IndexStrategyStorage storage ts)
    {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ts.slot := storagePosition
        }
    }
}
