// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IBasePool_OCY_Convex_C {
    function add_liquidity(uint256[] memory _amounts, uint256 _min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[] memory min_amounts) external;
}

interface IBaseRewardPool_OCY_Convex_C {
    function extraRewards(uint256 index) external view returns(address);
    function extraRewardsLength() external view returns(uint256);
    function rewardToken() external view returns(address);
    function getReward() external returns(bool);
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns(bool);
}

interface IRewardToken_OCY_Convex_C {
    function token() external view returns(address);
}

interface IBooster_OCY_Convex_C {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
}

interface IZivoeGlobals_OCY_Convex_C {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}



/// @notice This contract allocates stablecoins to the PYUSD/USDC base-pool and stakes the LP tokens on Convex.
contract OCY_Convex_C is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    /// @dev Tokens.
    address public constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8; /// @dev Index 0, BasePool
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  /// @dev Index 1, BasePool

    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;   /// @dev Native Reward #1
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;   /// @dev Native Reward #2

    /// @dev Convex information.
    address public convexDeposit = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public convexPoolToken = 0x383E6b4437b59fff47B619CBA855CA29342A8559;
    address public convexRewards = 0xc583e81bB36A1F620A804D8AF642B63b0ceEb5c0;

    uint256 public convexPoolID = 270;

    /// @dev Curve information.
    address public curveBasePool = 0x383E6b4437b59fff47B619CBA855CA29342A8559;
    address public curveBasePoolToken = 0x383E6b4437b59fff47B619CBA855CA29342A8559;



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

    /// @notice Emitted during updateOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public pure override returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public pure override returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerMulti().
    function canPullMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(
            asset == PYUSD || asset == USDC,
            "OCY_Convex_C::pushToLocker() asset != PYUSD && asset != USDC"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);

        (uint _min_mint_amountBP) = abi.decode(data, (uint));

        if (asset == PYUSD) {
            // Allocate PYUSD to Curve BasePool
            IERC20(PYUSD).safeIncreaseAllowance(curveBasePool, amount);
            uint256[] memory _amounts = new uint[](2);
            _amounts[0] = amount;
            IBasePool_OCY_Convex_C(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(PYUSD).allowance(address(this), curveBasePool) == 0);
        }
        else {
            // Allocate USDC to Curve BasePool
            IERC20(USDC).safeIncreaseAllowance(curveBasePool, amount);
            uint256[] memory _amounts = new uint[](2);
            _amounts[1] = amount;
            IBasePool_OCY_Convex_C(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(USDC).allowance(address(this), curveBasePool) == 0);
        }

        // Stake CurveLP tokens to Convex
        uint balCurveBasePoolToken = IERC20(curveBasePoolToken).balanceOf(address(this));
        IERC20(curveBasePoolToken).safeIncreaseAllowance(convexDeposit, balCurveBasePoolToken);
        IBooster_OCY_Convex_C(convexDeposit).deposit(convexPoolID, balCurveBasePoolToken, true);
        assert(IERC20(curveBasePoolToken).allowance(address(this), convexDeposit) == 0);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_C::pullFromLocker() asset != convexPoolToken");
        
        claimRewards(false);

        // Withdraw from ConvexRewards and unstake CurveLP tokens from ConvexBooster
        IBaseRewardPool_OCY_Convex_C(convexRewards).withdrawAndUnwrap(
            IERC20(convexRewards).balanceOf(address(this)), false
        );
        
        (uint _bp_min0, uint _bp_min1) = abi.decode(data, (uint, uint));
        
        // Burn BasePool Tokens
        uint256[] memory _min_amounts_bp = new uint[](2);
        _min_amounts_bp[0] = _bp_min0;
        _min_amounts_bp[1] = _bp_min1;
        IBasePool_OCY_Convex_C(curveBasePool).remove_liquidity(
            IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts_bp
        );

        // Return tokens to DAO
        IERC20(PYUSD).safeTransfer(owner(), IERC20(PYUSD).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_C::pullFromLockerPartial() asset != convexPoolToken");
        
        claimRewards(false);

        // Withdraw from ConvexRewards and unstake CurveLP tokens from ConvexBooster
        IBaseRewardPool_OCY_Convex_C(convexRewards).withdrawAndUnwrap(amount, false);
        
        (uint _bp_min0, uint _bp_min1) = abi.decode(data, (uint, uint));
        
        // Burn BasePool Tokens
        uint256[] memory _min_amounts_bp = new uint[](2);
        _min_amounts_bp[0] = _bp_min0;
        _min_amounts_bp[1] = _bp_min1;
        IBasePool_OCY_Convex_C(curveBasePool).remove_liquidity(
            IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts_bp
        );

        // Return tokens to DAO
        IERC20(PYUSD).safeTransfer(owner(), IERC20(PYUSD).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
    }

    /// @notice Claims rewards and forward them to the OCT_YDL.
    /// @param extra Flag for claiming extra rewards.
    function claimRewards(bool extra) public nonReentrant {
        IBaseRewardPool_OCY_Convex_C(convexRewards).getReward();

        // Native Rewards (CRV, CVX)
        uint256 rewardsCRV = IERC20(CRV).balanceOf(address(this));
        uint256 rewardsCVX = IERC20(CVX).balanceOf(address(this));
        if (rewardsCRV > 0) { IERC20(CRV).safeTransfer(OCT_YDL, rewardsCRV); }
        if (rewardsCVX > 0) { IERC20(CVX).safeTransfer(OCT_YDL, rewardsCVX); }

        // Extra Rewards
        if (extra) {
            uint256 extraRewardsLength = IBaseRewardPool_OCY_Convex_C(convexRewards).extraRewardsLength();
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address rewardContract = IBaseRewardPool_OCY_Convex_C(convexRewards).extraRewards(i);
                address rewardToken = IRewardToken_OCY_Convex_C(
                    IBaseRewardPool_OCY_Convex_C(rewardContract).rewardToken()
                ).token();
                uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this));
                if (rewardAmount > 0) { IERC20(rewardToken).safeTransfer(OCT_YDL, rewardAmount); }
            }
        }
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function updateOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_Convex_C(GBL).ZVL(), 
            "OCY_Convex_C::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_C(GBL).ZVL()"
        );
        require(_OCT_YDL != address(0), "OCY_Convex_C::updateOCTYDL() _OCT_YDL == address(0)");
        emit UpdatedOCTYDL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

}