// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../../CompositePlus.sol";

/**
 * @title BTCB+ token contract.
 * 
 * Users can mint BTCB+ with both ERC20 BTC token or ERC20 BTC LP token. 1 ERC20 BTC mints 1 BTCB+.
 * The BTCB+ balance increases as interest is accrued with the tokens used to mint BTCB+.
 *
 * BTCB+ is a composite plus token backed by a basket of BTC pegged single plus tokens, e.g. renCrv+, cWBTCB+.
 */
contract BTCBPlus is CompositePlus {

    /**
     * @dev Initializes the BTCB+ contract.
     */
    function initialize() public initializer {
        CompositePlus.initialize("BTCB Plus", "BTCB+");
    }
}