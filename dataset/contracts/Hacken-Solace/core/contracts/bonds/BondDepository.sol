// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./../utils/Factory.sol";
import "./../utils/Governable.sol";
import "./../interfaces/ISOLACE.sol";
import "./../interfaces/bonds/IBondDepository.sol";

/**
 * @title BondDepository
 * @author solace.fi
 * @notice Factory and manager of [`Bond Tellers`](./BondTellerBase).
 */
contract BondDepository is IBondDepository, Governable {

    /// @notice Native [**SOLACE**](./../SOLACE) Token.
    address public override solace;

    /// @notice Returns true if the address is a teller.
    mapping(address => bool) public override isTeller;

    /**
     * @notice Constructs the BondDepository contract.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param solace_ Address of [**SOLACE**](./../SOLACE).
     */
    constructor(address governance_, address solace_) Governable(governance_) {
        require(solace_ != address(0x0), "zero address solace");
        solace = solace_;
    }

    /***************************************
    TELLER MANAGEMENT FUNCTIONS
    ***************************************/

    /**
     * @notice Adds a teller.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param teller The teller to add.
     */
    function addTeller(address teller) external override onlyGovernance {
        isTeller[teller] = true;
        emit TellerAdded(teller);
    }

    /**
     * @notice Adds a teller.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param teller The teller to remove.
     */
    function removeTeller(address teller) external override onlyGovernance {
        isTeller[teller] = false;
        emit TellerRemoved(teller);
    }

    /***************************************
    FUND MANAGEMENT FUNCTIONS
    ***************************************/

    /**
     * @notice Sends [**SOLACE**](./../SOLACE) to the teller.
     * Can only be called by tellers.
     * @param amount The amount of [**SOLACE**](./../SOLACE) to send.
     */
    function pullSolace(uint256 amount) external override {
        // can only be called by authorized minters
        require(isTeller[msg.sender], "!teller");
        // mint new SOLACE
        ISOLACE(solace).mint(msg.sender, amount);
    }
}
