// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "../libs/MinerTypes.sol";

interface IMinerList {
    function list(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (bool);

    function count(
        MinerTypes.NodeType nodeType
    ) external view returns (uint256);

    function isMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (bool);

    function addMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external;

    function deleteMiner(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external;
}
