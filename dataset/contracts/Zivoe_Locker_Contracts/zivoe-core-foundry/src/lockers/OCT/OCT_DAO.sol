// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../Utility/ZivoeSwapper.sol";

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCT_DAO {
    /// @notice Returns the address of ZivoeDAO.
    function DAO() external view returns (address);

    /// @notice Returns true if an address is whitelisted as a keeper.
    /// @return keeper Equals "true" if address is a keeper, "false" if not.
    function isKeeper(address) external view returns (bool keeper);
}



/// @notice This contract converts assets and forwards them to the DAO.
contract OCT_DAO is ZivoeLocker, ZivoeSwapper, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCT_DAO contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    constructor(address DAO, address _GBL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during convertAndForward().
    /// @param  asset The "asset" being converted.
    /// @param  toAsset The ERC20 that we are converting "asset" to.
    /// @param  amountFrom The amount being converted.
    /// @param  amountTo The amount received from conversion.
    event AssetConvertedForwarded(address indexed asset, address indexed toAsset, uint256 amountFrom, uint256 amountTo);



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

    /// @notice Converts an asset and forwards it to the DAO.
    /// @param  asset The asset to convert.
    /// @param  toAsset The ERC20 that we are converting "asset" to. 
    /// @param  data The payload containing conversion data, consumed by 1INCH_V5.
    function convertAndForward(address asset, address toAsset, bytes calldata data) external nonReentrant {
        require(
            IZivoeGlobals_OCT_DAO(GBL).isKeeper(_msgSender()), 
            "OCT_DAO::convertAndForward !isKeeper(_msgSender())"
        );
        uint256 amountFrom = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeIncreaseAllowance(router1INCH_V5, amountFrom);
        convertAsset(asset, toAsset, amountFrom, data);
        if (IERC20(asset).allowance(address(this), router1INCH_V5) > 0) {
            IERC20(asset).safeDecreaseAllowance(router1INCH_V5, IERC20(asset).allowance(address(this), router1INCH_V5));
        }
        uint balToAsset = IERC20(toAsset).balanceOf(address(this));
        emit AssetConvertedForwarded(asset, toAsset, amountFrom, balToAsset);
        IERC20(toAsset).safeTransfer(IZivoeGlobals_OCT_DAO(GBL).DAO(), balToAsset);
    }

}