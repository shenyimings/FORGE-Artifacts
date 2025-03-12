// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice This contract is for testing generic ERC20 ZivoeLocker functions (inherited non-overridden functions).
contract OCG_ERC20_FreeClaim is ZivoeLocker {
    
    using SafeERC20 for IERC20;

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

    /// @notice Allows any external account to claim an ERC20 token from this contract.
    /// @param  token The token to claim.
    /// @param  amount The amount of "token" to claim.
    function claim(address token, uint256 amount) external {
        IERC20(token).safeTransfer(_msgSender(), amount);
    }

    /// @notice Allows any external account to forward an ERC20 token from this contract.
    /// @param  token The token to claim.
    /// @param  amount The amount of "token" to claim.
    /// @param  to The address to forward tokens to.
    function forward(address token, uint256 amount, address to) external {
        IERC20(token).safeTransfer(to, amount);
    }
    
}
