// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/**
 * @title MinerTypes
 * @dev A library that contains Miner & Node structure
 */
library MinerTypes {
    /// @notice miner struct that contains its node type and its existence
    struct Miner {
        NodeType nodeType;
        bool exist;
    }

    /// @notice node type for each miner
    enum NodeType {
        Meta,
        MacroArchive,
        MacroFullnode,
        MacroLight,
        Micro
    }
}
