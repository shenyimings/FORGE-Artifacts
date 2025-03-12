// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "../libs/MinerTypes.sol";

interface IMinerHealthCheck {
    function status(
        address minerAddress,
        MinerTypes.NodeType miner
    ) external view returns (bool);

    function dailyNodesActivities(
        uint256 date,
        MinerTypes.NodeType nodeType
    ) external view returns (uint256);

    function dailyNodeActivity(
        uint256 date,
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external view returns (uint256);

    function manualPing(
        address minerAddress,
        MinerTypes.NodeType nodeType
    ) external;
}
