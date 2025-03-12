// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IOUSD_OCY_OUSD {
    function rebaseOptIn() external;
}

interface IZivoeGlobals_OCY_OUSD {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}


/// @notice This contract escrows OUSD and handles accounting for yield distributions.
contract OCY_OUSD is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                                                   /// @dev The ZivoeGlobals contract.
    address public immutable OUSD = 0x2A8e1E676Ec238d8A992307B495b45B3fEAa5e86;     /// @dev Origin Dollar contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    uint256 public basis;                           /// @dev The basis of OUSD for distribution accounting.



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCY_OUSD contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _OCT_YDL The OCT_YDL (Treasury and ZivoeSwapper) contract.
    constructor(address DAO, address _GBL, address _OCT_YDL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
        OCT_YDL = _OCT_YDL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during pushToLocker(), pullFromLocker(), pullFromLockerPartial().
    /// @param  priorBasis The prior value of basis.
    /// @param  newBasis The new value of basis.
    event BasisAdjusted(uint256 priorBasis, uint256 newBasis);

    /// @notice Emitted during updateOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    /// @notice Emitted during forwardYield().
    /// @param  amount The amount of OUSD forwarded.
    /// @param  newBasis The new basis value.
    event YieldForwarded(uint256 amount, uint256 newBasis);


    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public pure override returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public pure override returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pushToLocker() asset != OUSD");
        emit BasisAdjusted(basis, basis + amount);
        basis += amount;
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pullFromLocker() asset != OUSD");

        forwardYield();
        
        emit BasisAdjusted(basis, 0);
        basis = 0;
        IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == OUSD, "OCY_OUSD::pullFromLockerPartial() asset != OUSD");

        forwardYield();

        // We are assuming basis == IERC20(OUSD).balanceOf(address(this)) after forwardYield().
        emit BasisAdjusted(basis, basis - amount);
        basis -= amount;

        IERC20(asset).safeTransfer(owner(), amount);
    }

    /// @notice Ensures this locker has opted-in for the OUSD rebase.
    /// @dev    Only callable once, reverts afterwards once this contract is already opted-in.
    function rebase() public {
        IOUSD_OCY_OUSD(OUSD).rebaseOptIn();
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function updateOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_OUSD(GBL).ZVL(), 
            "OCY_OUSD::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_OUSD(GBL).ZVL()"
        );
        require(_OCT_YDL != address(0), "OCY_OUSD::updateOCTYDL() _OCT_YDL == address(0)");
        emit UpdatedOCTYDL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

    /// @notice Forwards excess basis to OCT_YDL for conversion.
    function forwardYield() public nonReentrant {
        uint256 amountOUSD = IERC20(OUSD).balanceOf(address(this));
        if (amountOUSD > basis) {
            IERC20(OUSD).safeTransfer(OCT_YDL, amountOUSD - basis);
            emit YieldForwarded(amountOUSD - basis, IERC20(OUSD).balanceOf(address(this)));
        }
        basis = IERC20(OUSD).balanceOf(address(this));
    }

}