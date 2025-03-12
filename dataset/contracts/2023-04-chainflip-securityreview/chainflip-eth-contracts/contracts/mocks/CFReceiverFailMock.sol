pragma solidity ^0.8.0;

import "../abstract/CFReceiver.sol";
import "../abstract/Shared.sol";

/**
 * @title    CFReceiverMock
 * @dev      Mock implementation of CFReceiver for testing purposes.
 */

contract CFReceiverFailMock is CFReceiver, Shared {
    constructor(address _cfVault) CFReceiver(_cfVault) nzAddr(cfVault) {}

    /* solhint-disable no-unused-vars */
    function _cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) internal override {
        _revert();
    }

    function _cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) internal override {
        _revert();
    }

    /* solhint-enable no-unused-vars */

    function revertExternalCall() external pure {
        _revert();
    }

    function _revert() internal pure {
        revert("CFReceiverFail: call reverted");
    }
}
