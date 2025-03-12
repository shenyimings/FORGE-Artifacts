pragma solidity ^0.8.0;

import "../abstract/CFReceiver.sol";
import "../abstract/Shared.sol";

/**
 * @title    CFReceiverMock
 * @dev      Mock implementation of CFReceiver for testing purposes.
 */

contract CFReceiverMock is CFReceiver, Shared {
    event ReceivedxSwapAndCall(
        uint32 srcChain,
        bytes srcAddress,
        bytes message,
        address token,
        uint256 amount,
        uint256 nativeReceived
    );
    event ReceivedxCall(uint32 srcChain, bytes srcAddress, bytes message);

    constructor(address _cfVault) CFReceiver(_cfVault) nzAddr(_cfVault) {}

    function _cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) internal override {
        emit ReceivedxSwapAndCall(srcChain, srcAddress, message, token, amount, msg.value);
    }

    function _cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) internal override {
        emit ReceivedxCall(srcChain, srcAddress, message);
    }
}
