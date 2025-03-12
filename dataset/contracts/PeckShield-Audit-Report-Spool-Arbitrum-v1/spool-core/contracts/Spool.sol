// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./spool/SpoolExternal.sol";

/**
 * @notice Implementation of the central Spool contract.
 *
 * @dev
 * The Spool implementation is the central part of the system.
 * All the assets flow through this contract and are deposited
 * to the integrated protocols.
 *
 * Spool implementation consists of following contracts:
 * 1. BaseStorage: stores common variables with all the strategy adapters (they are execuret as delegatecode)
 * 2. SpoolBase: holds Spool state variables and provides some of the common vault functions
 * 3. SpoolStrategy: implements the logic of how to interact with the strategies
 * 4. SpoolDoHardWork: implements functions to process the do hard work
 * 5. SpoolReallocation: adjusts vault reallocation that takes place at the next do hard work
 * 6. SpoolExternal: exposes functons to interact with the Spool from the vault (deposit/withdraw/redeem)
 * 7. Spool: implements a constructor to deploy a contracts
 */
contract Spool is SpoolExternal {

    /**
     * @notice Initializes the central Spool contract values
     *
     * @param _spoolOwner the spool owner contract
     * @param _controller responsible for providing the source of truth
     * @param _strategyRegistry the strategy registry contract address
     * @param _fastWithdraw allows fast withdraw of user shares
     */
    constructor(
        ISpoolOwner _spoolOwner,
        IController _controller,
        IStrategyRegistry _strategyRegistry,
        address _fastWithdraw
    )
        SpoolBase(
            _spoolOwner,
            _controller,
            _strategyRegistry,
            _fastWithdraw
        )
    {}
}
