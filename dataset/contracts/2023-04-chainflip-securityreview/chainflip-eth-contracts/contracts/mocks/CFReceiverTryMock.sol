pragma solidity ^0.8.0;

import "../abstract/CFReceiver.sol";
import "../abstract/Shared.sol";
import "../mocks/CFReceiverFailMock.sol";

/**
 * @title    CFReceiverTryMock
 * @dev      Mock implementation of CFReceiver for testing purposes.
 */

contract CFReceiverTryMock is CFReceiver, Shared {
    event FailedExternalCall(string revertString);

    address private _receiverFail;

    constructor(address cfVault, address receiverFail) CFReceiver(cfVault) nzAddr(cfVault) {
        _receiverFail = receiverFail;
    }

    /* solhint-disable no-unused-vars */
    function _cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) internal override {
        _handleFailedCall();
    }

    function _cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) internal override {
        _handleFailedCall();
    }

    /* solhint-enable no-unused-vars */
    function _handleFailedCall() internal {
        // Mimicking a contract catching an external call that fails
        try CFReceiverFailMock(_receiverFail).revertExternalCall() {} catch Error(string memory revertString) {
            // Specific error case since we expect a revert string.
            emit FailedExternalCall(revertString);
        } catch {
            // Handle other revert cases.
        }
    }
}
