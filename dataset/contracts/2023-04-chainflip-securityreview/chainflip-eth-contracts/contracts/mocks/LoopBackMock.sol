pragma solidity ^0.8.0;

import "../abstract/CFReceiver.sol";
import "../abstract/Shared.sol";
import "../interfaces/IVault.sol";

/**
 * @title    LoopBackMock
 * @dev      Mock of a loopback. To make it simpler we don't bother decoding the
 *           message and the callback to the Vault contract is hardcoded.
 */
contract LoopBackMock is CFReceiver, Shared {
    uint256 private constant DEFAULT_GAS = 200000;

    constructor(address _cfVault) CFReceiver(_cfVault) nzAddr(_cfVault) {}

    function _cfReceive(
        uint32 srcChain,
        bytes calldata srcAddress,
        bytes calldata message,
        address token,
        uint256 amount
    ) internal override {
        if (token == _NATIVE_ADDR) {
            // Just health check for this mock. It will never revert.
            require(msg.value == amount, "LoopbackMock: msg.value != amount");
            IVault(cfVault).xCallNative{value: amount}(
                srcChain,
                srcAddress,
                0,
                message,
                DEFAULT_GAS,
                abi.encodePacked(address(this))
            );
        } else {
            require(IERC20(token).approve(msg.sender, amount));
            IVault(cfVault).xCallToken(
                srcChain,
                srcAddress,
                1,
                message,
                DEFAULT_GAS,
                IERC20(token),
                amount,
                abi.encodePacked(address(this))
            );
        }
    }

    function _cfReceivexCall(uint32 srcChain, bytes calldata srcAddress, bytes calldata message) internal override {
        uint256 nativeBalance = address(this).balance;
        IVault(cfVault).xCallNative{value: nativeBalance}(
            srcChain,
            srcAddress,
            0,
            message,
            DEFAULT_GAS,
            abi.encodePacked(address(this))
        );
    }

    receive() external payable {}
}
