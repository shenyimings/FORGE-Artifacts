// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

/**
 * @title BondDepository
 * @author solace.fi
 * @notice Factory and manager of [`Bond Tellers`](./IBondTeller).
 */
interface IBondDepository {

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when a teller is added.
    event TellerAdded(address indexed teller);
    /// @notice Emitted when a teller is removed.
    event TellerRemoved(address indexed teller);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /// @notice Native [**SOLACE**](./../../SOLACE) Token.
    function solace() external view returns (address solace_);

    /// @notice Returns true if the address is a teller.
    function isTeller(address teller) external view returns (bool isTeller_);

    /***************************************
    TELLER MANAGEMENT FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a teller.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param teller The teller to add.
     */
    function addTeller(address teller) external;

    /**
     * @notice Adds a teller.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param teller The teller to remove.
     */
    function removeTeller(address teller) external;

    /***************************************
    FUND MANAGEMENT FUNCTIONS
    ***************************************/

    /**
     * @notice Sends [**SOLACE**](./../../SOLACE) to the teller.
     * Can only be called by tellers.
     * @param amount The amount of [**SOLACE**](./../../SOLACE) to send.
     */
    function pullSolace(uint256 amount) external;
}
