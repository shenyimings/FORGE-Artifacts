// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

import {FxBaseChildTunnel} from "../tunnel/FxBaseChildTunnel.sol";
import "../pools/IChildPool.sol";

/**
 * @title FxStateChildTunnel
 */
contract FxStateChildTunnel is FxBaseChildTunnel, Ownable {
    uint256 public latestStateId;
    address public latestRootMessageSender;
    bytes public latestData;
    address public pool;

    constructor(address _fxChild) FxBaseChildTunnel(_fxChild) {}

    function _processMessageFromRoot(
        uint256 stateId,
        address sender,
        bytes memory data
    ) internal override validateSender(sender) {
        latestStateId = stateId;
        latestRootMessageSender = sender;
        latestData = data;
    }

    function sendMessageToRoot(bytes memory message) public {
        require(msg.sender == pool, "!pool");

        _sendMessageToRoot(message);
    }

    function readData() public view returns (uint256, uint256, ShuttleProcessingStatus) {
      (uint256 shuttleNumber, uint256 amount, ShuttleProcessingStatus shuttleProcessingStatus) = abi.decode(
            latestData,
            (uint256, uint256, ShuttleProcessingStatus)
        );

        return (shuttleNumber, amount, shuttleProcessingStatus);
    }

    function setPool(address _pool) external onlyOwner {
        pool = _pool;
    }
}
