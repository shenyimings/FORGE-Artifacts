// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.6;


/**
 * @title Faucet
 * @author solace.fi
 * @notice Drips [**SOLACE**](../SOLACE).
 *
 * Useful for testing but should NOT be used in production.
 */
interface IFaucet {

    /**
     * @notice Drips [**SOLACE**](../SOLACE) to msg.sender.
     */
    function drip() external;
}
