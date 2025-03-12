// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCT_ZVL {
    /// @notice Returns the address of ZivoeToken ($ZVE) contract.
    function ZVE() external view returns (address);

    /// @notice Returns the address of Zivoe Laboratory.
    function ZVL() external view returns (address);
}



/// @notice This contract escrows ZVE and enables ZVL to claim directly.
contract OCT_ZVL is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCT_ZVL contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during claim().
    /// @param  asset The "asset" being claimed.
    /// @param  amount The amount being claimed.
    event Claimed(address indexed asset, uint256 amount);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerMulti().
    function canPushMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMultiPartial().
    function canPullMultiPartial() public override pure returns (bool) { return true; }

    /// @notice Claims $ZVE.
    function claim() external nonReentrant {
        require(_msgSender() == IZivoeGlobals_OCT_ZVL(GBL).ZVL(), "_msgSender() != IZivoeGlobals_OCT_ZVL(GBL).ZVL()");
        address ZVE = IZivoeGlobals_OCT_ZVL(GBL).ZVE();
        uint256 amount = IERC20(ZVE).balanceOf(address(this));
        IERC20(ZVE).safeTransfer(_msgSender(), amount);
        emit Claimed(ZVE, amount);
    }

}