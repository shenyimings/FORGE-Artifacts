// SPDX-License-Identifier: MIT

pragma solidity 0.7.3;

import "../../fx-portal/contracts/tunnel/FxBaseChildTunnel.sol";
import "../IAppProxyFactoryBridged.sol";

/**
 * @title  GovernanceBridgeL2
 * @author Props
 * @dev    This contract is responsible for relaying governance actions to L1.
 */
contract GovernanceBridgeL2 is FxBaseChildTunnel {
    address public controller;

    constructor(address _fxChild, address _controller) FxBaseChildTunnel(_fxChild) {
        controller = _controller;
    }

    /**
     * @dev Relay a governance action to L1.
     * @param _target The target contract to get called
     * @param _callData The calldata of the contract call
     */
    function relayAction(address _target, bytes calldata _callData) external {
        require(msg.sender == controller, "Unauthorized");
        _sendMessageToRoot(abi.encode(_target, _callData));
    }

    function _processMessageFromRoot(
        uint256,
        address,
        bytes memory
    ) internal pure override {
        // We don't relay messages from L1 to L2 over this bridge
    }
}
