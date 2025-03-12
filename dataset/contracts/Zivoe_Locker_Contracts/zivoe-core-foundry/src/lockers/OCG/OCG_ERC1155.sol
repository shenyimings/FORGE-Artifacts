// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

/// @notice This contract is for testing generic ERC1155 ZivoeLocker functions (inherited non-overridden functions).
contract OCG_ERC1155 is ZivoeLocker {
    
    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_Generic.sol contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    constructor(address DAO) {
        transferOwnership(DAO);
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLockerERC1155().
    function canPushERC1155() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerERC1155().
    function canPullERC1155() public pure override returns (bool) {
        return true;
    }


}
