// SPDX-FileCopyrightText: 2021 ShardLabs
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

interface IFxStateChildTunnel {
    function latestStateId() external view returns (uint256);

    function latestRootMessageSender() external view returns (address);

    function latestData() external view returns (bytes memory);

    function sendMessageToRoot(bytes memory message) external;

    function setFxRootTunnel(address _fxRootTunnel) external;

    function getReserves() external view returns (uint256, uint256);
}
