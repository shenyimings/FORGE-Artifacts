// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title Mock Faulty Receiver
 * @author solace.fi
 * @notice A contract that throws if sent ETH.
 */
contract MockFaultyReceiver {

    /**
     * @notice Fallback function to allow contract to receive **ETH**.
     */
    receive () external payable {
        revert("get stickbugged");
    }

    /**
     * @notice Fallback function to allow contract to receive **ETH**.
     */
    fallback () external payable {
        revert("get stickbugged");
    }

    /**
     * @notice Forwards a call to another contract.
     * Do not use in production.
     * @param to Contract to call.
     * @param data Data to send.
     */
    function forwardCall(address payable to, bytes calldata data) external payable {
        (bool success, ) = to.call{value: msg.value}(data);
        require(success, "could not forward call");
    }
}
