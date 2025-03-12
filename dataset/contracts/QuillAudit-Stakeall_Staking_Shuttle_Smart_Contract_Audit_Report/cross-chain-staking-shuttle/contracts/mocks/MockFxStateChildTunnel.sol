// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../pools/IChildPool.sol";

contract MockFxStateChildTunnel {
    bytes public data;
    bytes public latestData;

    function sendMessageToRoot(bytes memory _data) public {
        data = _data;
    }

    function setLatestData(bytes memory _latestData) public {
        latestData = _latestData;
    }

    function readData()
        public
        view
        returns (
            uint256,
            uint256,
            ShuttleProcessingStatus
        )
    {
        (
            uint256 shuttleNumber,
            uint256 amount,
            ShuttleProcessingStatus shuttleProcessingStatus
        ) = abi.decode(latestData, (uint256, uint256, ShuttleProcessingStatus));

        return (shuttleNumber, amount, shuttleProcessingStatus);
    }
}
