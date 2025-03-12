// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

struct TemplateStorage {
    string dataA;
    uint256 dataB;
}

library TemplateStorageLib {
    // keccak256("block42.storage.template.strategy");
    // solhint-disable-next-line const-name-snakecase
    bytes32 private constant storagePosition =
        0x2aa4f97c53f130d09247b52aa489416dfecd008354a1c3a83587b5d6ed2b6da1;

    function getStorage() internal pure returns (TemplateStorage storage ts) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ts.slot := storagePosition
        }
    }
}
