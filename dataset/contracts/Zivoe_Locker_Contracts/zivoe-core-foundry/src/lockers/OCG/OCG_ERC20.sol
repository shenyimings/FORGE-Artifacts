// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

/// @notice This contract is for testing generic ERC20 ZivoeLocker functions (inherited non-overridden functions).
contract OCG_ERC20 is ZivoeLocker {
    
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

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pushToLockerMulti().
    function canPushMulti() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerMultiPartial().
    function canPullMultiPartial() public pure override returns (bool) {
        return true;
    }


}
