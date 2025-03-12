// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IBasePool_OCY_Convex_B {
    function add_liquidity(uint256[4] memory _amounts, uint256 _min_mint_amount) external;
    function remove_liquidity(uint256 _amount, uint256[4] memory min_amounts) external;
}

interface IBaseRewardPool_OCY_Convex_B {
    function extraRewards(uint256 index) external view returns(address);
    function extraRewardsLength() external view returns(uint256);
    function rewardToken() external view returns(IERC20);
    function getReward() external returns(bool);
    function withdrawAndUnwrap(uint256 _amount, bool _claim) external returns(bool);
}

interface IBooster_OCY_Convex_B {
    function deposit(uint256 _pid, uint256 _amount, bool _stake) external returns(bool);
    function withdraw(uint256 _pid, uint256 _amount) external returns(bool);
}

interface IZivoeGlobals_OCY_Convex_B {
    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);
}



/// @notice This contract allocates stablecoins to the sUSD base-pool and stakes the LP tokens on Convex.
contract OCY_Convex_B is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;                   /// @dev The ZivoeGlobals contract.

    address public OCT_YDL;                         /// @dev The OCT_YDL contract.

    /// @dev Tokens.
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;   /// @dev Index 0, BasePool
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  /// @dev Index 1, BasePool
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;  /// @dev Index 2, BasePool
    address public constant sUSD = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;  /// @dev Index 3, BasePool

    address public constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;   /// @dev Native Reward #1
    address public constant CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;   /// @dev Native Reward #2

    /// @dev Convex information.
    address public convexDeposit = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31;
    address public convexPoolToken = 0xC25a3A3b969415c80451098fa907EC722572917F;
    address public convexRewards = 0x22eE18aca7F3Ee920D01F25dA85840D12d98E8Ca;

    uint256 public convexPoolID = 4;

    /// @dev Curve information.
    address public curveBasePool = 0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address public curveBasePoolToken = 0xC25a3A3b969415c80451098fa907EC722572917F;



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

    /// @notice Permission for owner to call pushToLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Migrates specific amount of ERC20 from owner() to locker.
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pushToLocker(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(
            asset == DAI || asset == USDC || asset == USDT || asset == sUSD, 
            "OCY_Convex_B::pushToLocker() asset != DAI && asset != USDC && asset != USDT && asset != sUSD"
        );
        IERC20(asset).safeTransferFrom(owner(), address(this), amount);

        (uint _min_mint_amountBP) = abi.decode(data, (uint));

        if (asset == DAI) {
            // Allocate DAI to Curve BasePool
            IERC20(DAI).safeIncreaseAllowance(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[0] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(DAI).allowance(address(this), curveBasePool) == 0);
        }
        else if (asset == USDC) {
            // Allocate USDC to Curve BasePool
            IERC20(USDC).safeIncreaseAllowance(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[1] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(USDC).allowance(address(this), curveBasePool) == 0);
        }
        else if (asset == USDT) {
            // Allocate USDT to Curve BasePool
            IERC20(USDT).safeIncreaseAllowance(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[2] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(USDT).allowance(address(this), curveBasePool) == 0);
        }
        else {
            // Allocate sUSD to Curve BasePool
            IERC20(sUSD).safeIncreaseAllowance(curveBasePool, amount);
            uint256[4] memory _amounts;
            _amounts[3] = amount;
            IBasePool_OCY_Convex_B(curveBasePool).add_liquidity(_amounts, _min_mint_amountBP);
            assert(IERC20(sUSD).allowance(address(this), curveBasePool) == 0);
        }

        // Stake CurveLP tokens to Convex
        uint balCurveBasePoolToken = IERC20(curveBasePoolToken).balanceOf(address(this));
        IERC20(curveBasePoolToken).safeIncreaseAllowance(convexDeposit, balCurveBasePoolToken);
        IBooster_OCY_Convex_B(convexDeposit).deposit(convexPoolID, balCurveBasePoolToken, true);
        assert(IERC20(curveBasePoolToken).allowance(address(this), convexDeposit) == 0);
    }

    /// @notice Migrates entire ERC20 balance from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_B::pullFromLocker() asset != convexPoolToken");
        
        claimRewards(false);

        // Withdraw from ConvexRewards and unstake CurveLP tokens from ConvexBooster
        IBaseRewardPool_OCY_Convex_B(convexRewards).withdrawAndUnwrap(
            IERC20(convexRewards).balanceOf(address(this)), false
        );
        
        (uint _bp_min0, uint _bp_min1, uint _bp_min2, uint _bp_min3) = abi.decode(data, (uint, uint, uint, uint));
        
        // Burn BasePool Tokens
        uint256[4] memory _min_amounts_bp;
        _min_amounts_bp[0] = _bp_min0;
        _min_amounts_bp[1] = _bp_min1;
        _min_amounts_bp[2] = _bp_min2;
        _min_amounts_bp[3] = _bp_min3;
        IBasePool_OCY_Convex_B(curveBasePool).remove_liquidity(
            IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts_bp
        );

        // Return tokens to DAO
        IERC20(DAI).safeTransfer(owner(), IERC20(DAI).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(USDT).safeTransfer(owner(), IERC20(USDT).balanceOf(address(this)));
        IERC20(sUSD).safeTransfer(owner(), IERC20(sUSD).balanceOf(address(this)));
    }

    /// @notice Migrates specific amount of ERC20 from locker to owner().
    /// @param  asset The asset to migrate.
    /// @param  amount The amount of "asset" to migrate.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(address asset, uint256 amount, bytes calldata data) external override onlyOwner {
        require(asset == convexPoolToken, "OCY_Convex_B::pullFromLockerPartial() asset != convexPoolToken");
        
        claimRewards(false);

        // Withdraw from ConvexRewards and unstake CurveLP tokens from ConvexBooster
        IBaseRewardPool_OCY_Convex_B(convexRewards).withdrawAndUnwrap(amount, false);
        
        (uint _bp_min0, uint _bp_min1, uint _bp_min2, uint _bp_min3) = abi.decode(data, (uint, uint, uint, uint));
        
        // Burn BasePool Tokens
        uint256[4] memory _min_amounts_bp;
        _min_amounts_bp[0] = _bp_min0;
        _min_amounts_bp[1] = _bp_min1;
        _min_amounts_bp[2] = _bp_min2;
        _min_amounts_bp[3] = _bp_min3;
        uint256[4] memory _min_amounts;
        IBasePool_OCY_Convex_B(curveBasePool).remove_liquidity(
            IERC20(curveBasePoolToken).balanceOf(address(this)), _min_amounts_bp
        );

        // Return tokens to DAO
        IERC20(DAI).safeTransfer(owner(), IERC20(DAI).balanceOf(address(this)));
        IERC20(USDC).safeTransfer(owner(), IERC20(USDC).balanceOf(address(this)));
        IERC20(USDT).safeTransfer(owner(), IERC20(USDT).balanceOf(address(this)));
        IERC20(sUSD).safeTransfer(owner(), IERC20(sUSD).balanceOf(address(this)));
    }

    /// @notice Claims rewards and forward them to the OCT_YDL.
    /// @param extra Flag for claiming extra rewards.
    function claimRewards(bool extra) public nonReentrant {
        IBaseRewardPool_OCY_Convex_B(convexRewards).getReward();

        // Native Rewards (CRV, CVX)
        uint256 rewardsCRV = IERC20(CRV).balanceOf(address(this));
        uint256 rewardsCVX = IERC20(CVX).balanceOf(address(this));
        if (rewardsCRV > 0) { IERC20(CRV).safeTransfer(OCT_YDL, rewardsCRV); }
        if (rewardsCVX > 0) { IERC20(CVX).safeTransfer(OCT_YDL, rewardsCVX); }

        // Extra Rewards
        if (extra) {
            uint256 extraRewardsLength = IBaseRewardPool_OCY_Convex_B(convexRewards).extraRewardsLength();
            for (uint256 i = 0; i < extraRewardsLength; i++) {
                address rewardContract = IBaseRewardPool_OCY_Convex_B(convexRewards).extraRewards(i);
                uint256 rewardAmount = IBaseRewardPool_OCY_Convex_B(rewardContract).rewardToken().balanceOf(
                    address(this)
                );
                if (rewardAmount > 0) { IERC20(rewardContract).safeTransfer(OCT_YDL, rewardAmount); }
            }
        }
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function updateOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCY_Convex_B(GBL).ZVL(), 
            "OCY_Convex_B::updateOCTYDL() _msgSender() != IZivoeGlobals_OCY_Convex_B(GBL).ZVL()"
        );
        require(_OCT_YDL != address(0), "OCY_Convex_B::updateOCTYDL() _OCT_YDL == address(0)");
        emit UpdatedOCTYDL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }

}