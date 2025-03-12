// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
* @title This is a mock for testing only.
* @dev DO NOT deploy in production!
*/
contract MockAlteringReceive {
    bool private s_shouldRevertOnReceive;

    receive() external payable {
        if (s_shouldRevertOnReceive) {
            for(;;) {
                // infinite loop to consume all the gas
            }
        }
    }

    function startRevertingOnReceive() external {
        s_shouldRevertOnReceive = true;
    }
}
