// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

interface IZivoeGlobals_OCG_Defaults {
    function TLC() external view returns (address);
    function decreaseDefaults(uint256) external;
    function increaseDefaults(uint256) external;
}

/// @notice This contract is for testing default adjustments via ZivoeLocker.
contract OCG_Defaults is ZivoeLocker {
    
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public GBL;  /// @dev The ZivoeGlobals contract.


    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO, address _GBL) {
        transferOwnership(DAO);
        GBL = _GBL;
    }



    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures that the caller is the timelock contract.
    modifier onlyGovernance {
        require(
            _msgSender() == IZivoeGlobals_OCG_Defaults(GBL).TLC(),
            "OCG_Defaults::onlyGovernance() _msgSender!= IZivoeGlobals_OCG_Defaults(GBL).TLC()"
        );
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice This function will decrease the net defaults in the ZivoeGlobals contract.
    /// @param amount The amount by which the defaults should be reduced.
    function decreaseDefaults(uint256 amount) public onlyGovernance {
        IZivoeGlobals_OCG_Defaults(GBL).decreaseDefaults(amount);
    }


    /// @notice This function will increase the net defaults in the ZivoeGlobals contract.
    /// @param amount The amount by which the defaults should be increased.
    function increaseDefaults(uint256 amount) public onlyGovernance {
        IZivoeGlobals_OCG_Defaults(GBL).increaseDefaults(amount);
    }

}
