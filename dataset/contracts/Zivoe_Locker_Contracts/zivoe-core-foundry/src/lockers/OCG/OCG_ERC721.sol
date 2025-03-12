// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

/// @notice This contract is for testing generic ERC721 ZivoeLocker functions (inherited non-overridden functions).
contract OCG_ERC721 is ZivoeLocker {
    
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

    /// @notice Permission for owner to call pushToLockerERC721().
    function canPushERC721() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerERC721().
    function canPullERC721() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pushToLockerMultiERC721().
    function canPushMultiERC721() public pure override returns (bool) {
        return true;
    }

    /// @notice Permission for owner to call pullFromLockerMultiERC721().
    function canPullMultiERC721() public pure override returns (bool) {
        return true;
    }

}
