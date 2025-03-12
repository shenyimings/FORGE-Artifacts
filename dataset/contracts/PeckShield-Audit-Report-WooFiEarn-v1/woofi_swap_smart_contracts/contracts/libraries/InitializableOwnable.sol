// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title Ownable initializable contract.
 *
 * @notice Ownership related functions
 */
contract InitializableOwnable {
    address public _OWNER_;
    address public _NEW_OWNER_;
    bool internal _INITIALIZED_;

    // ============ Events ============

    event OwnershipTransferPrepared(address indexed previousOwner, address indexed newOwner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ============ Modifiers ============

    modifier notInitialized() {
        require(!_INITIALIZED_, 'InitializableOwnable: SHOULD_NOT_BE_INITIALIZED');
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _OWNER_, 'InitializableOwnable: NOT_OWNER');
        _;
    }

    // ============ Functions ============

    /// @dev Init _OWNER_ from newOwner and set _INITIALIZED_ as true
    /// @param newOwner new owner address
    function initOwner(address newOwner) public notInitialized {
        _INITIALIZED_ = true;
        _OWNER_ = newOwner;
    }

    /// @dev Set _NEW_OWNER_ from newOwner
    /// @param newOwner new owner address
    function transferOwnership(address newOwner) public onlyOwner {
        emit OwnershipTransferPrepared(_OWNER_, newOwner);
        _NEW_OWNER_ = newOwner;
    }

    /// @dev Set _OWNER_ from _NEW_OWNER_ and set _NEW_OWNER_ equal zero address
    function claimOwnership() public {
        require(msg.sender == _NEW_OWNER_, 'InitializableOwnable: INVALID_CLAIM');
        emit OwnershipTransferred(_OWNER_, _NEW_OWNER_);
        _OWNER_ = _NEW_OWNER_;
        _NEW_OWNER_ = address(0);
    }
}
