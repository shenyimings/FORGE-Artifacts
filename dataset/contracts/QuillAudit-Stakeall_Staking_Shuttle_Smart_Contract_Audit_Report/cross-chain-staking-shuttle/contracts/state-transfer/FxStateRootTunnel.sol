// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

import {FxBaseRootTunnel} from "../tunnel/FxBaseRootTunnel.sol";

/**
 * @title FxStateRootTunnel
 */
contract FxStateRootTunnel is FxBaseRootTunnel, Ownable {
    bytes public latestData;
    address public pool;

    constructor(address _checkpointManager, address _fxRoot) FxBaseRootTunnel(_checkpointManager, _fxRoot) {}

    function _processMessageFromChild(bytes memory data) internal override {
        latestData = data;
    }

    function sendMessageToChild(bytes memory message) public {
        require(msg.sender == pool, "!pool");

        _sendMessageToChild(message);
    }

    function readData() public view returns (uint256, uint256) {
      (uint256 batchNumber, uint256 amount) = abi.decode(
            latestData,
            (uint256, uint256)
        );

        return (batchNumber,amount);
    }

    function setPool(address _pool) external onlyOwner {
        pool = _pool;
    }
}
