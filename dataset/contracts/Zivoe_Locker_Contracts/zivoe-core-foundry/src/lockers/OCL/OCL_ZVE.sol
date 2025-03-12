// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IFactory_OCL_ZVE {
    /// @notice Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    /// @param tokenA Address of one of pair's tokens.
    /// @param tokenB Address of pair's other token.
    /// @return pair The address of the pair.
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IRouter_OCL_ZVE {
    /// @notice Adds liquidity in a pool with both ERC20 tokens A and B.
    /// @param tokenA A pool token.
    /// @param tokenB A pool token.
    /// @param amountADesired Amount tokenA to add as liquidity if B/A <= amountBDesired/amountADesired (A depreciates).
    /// @param amountBDesired Amount tokenB to add as liquidity if A/B <= amountADesired/amountBDesired (B depreciates).
    /// @param amountAMin Bounds B/A price max before the transaction reverts. Must be <= amountADesired.
    /// @param amountBMin Bounds A/B price max before the transaction reverts. Must be <= amountBDesired.
    /// @param to Recipient of the liquidity tokens.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @return amountA The amount of tokenA sent to the pool.
    /// @return amountB The amount of tokenB sent to the pool.
    /// @return liquidity The amount of liquidity tokens minted.
    function addLiquidity(
        address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, 
        uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    /// @notice Removes liquidity in a pool with both ERC20 tokens A and B.
    /// @param tokenA A pool token.
    /// @param tokenB A pool token.
    /// @param liquidity The amount of liquidity tokens to remove.
    /// @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert.
    /// @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert.
    /// @param to Recipient of the underlying assets.
    /// @param deadline Unix timestamp after which the transaction will revert.
    /// @return amountA The amount of tokenA received.
    /// @return amountB The amount of tokenB received.
    function removeLiquidity(
        address tokenA, address tokenB, uint256 liquidity, 
        uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface IZivoeGlobals_OCL_ZVE {
    /// @notice Returns the address of the Timelock contract.
    function TLC() external view returns (address);

    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);

    /// @notice Returns the address of the ZivoeToken contract.
    function ZVE() external view returns (address);

    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);

    /// @notice Returns true if an address is whitelisted as a keeper.
    function isKeeper(address) external view returns (bool);
}

interface IZivoeYDL_OCL_ZVE {
    /// @notice Returns the "stablecoin" that will be distributed via YDL.
    /// @return asset The address of the "stablecoin" that will be distributed via YDL.
    function distributedAsset() external view returns (address asset);
}


/// @notice This contract manages liquidity provisioning for a Uniswap v2 or Sushi pool.
///         This contract has the following responsibilities:
///           - Allocate capital to a $ZVE/pairAsset pool.
///           - Remove capital from a $ZVE/pairAsset pool.
///           - Forward yield (profits) every 30 days to the YDL with compounding mechanisms.
contract OCL_ZVE is ZivoeLocker, ReentrancyGuard {

    using SafeERC20 for IERC20;
    
    // ---------------------
    //    State Variables
    // ---------------------

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.
    address public immutable factory;           /// @dev Address for the Factory (Uniswap v2 or Sushi).
    address public immutable pairAsset;         /// @dev ERC20 that will be paired with $ZVE for Sushi pool.
    address public immutable router;            /// @dev Address for the Router (Uniswap v2 or Sushi).

    address public OCT_YDL;                     /// @dev Facilitates swaps and forwards distributedAsset() to YDL.
    
    uint256 public basis;                       /// @dev The basis used for forwardYield() accounting.
    uint256 public compoundingRateBIPS = 5000;  /// @dev The % of returns to retain, in BIPS.
    uint256 public nextYieldDistribution;       /// @dev Determines next available forwardYield() call.

    uint256 private constant BIPS = 10000;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCL_ZVE contract.
    /// @param DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param _GBL The ZivoeGlobals contract.
    /// @param _pairAsset ERC20 that will be paired with $ZVE for pool.
    /// @param  _OCT_YDL The contract that facilitates swaps and forwards distributedAsset() to YDL.
    constructor(address DAO, address _GBL, address _pairAsset, address _router, address _factory, address _OCT_YDL) {
        transferOwnershipAndLock(DAO);
        GBL = _GBL;
        pairAsset = _pairAsset;
        router = _router;
        factory = _factory;
        OCT_YDL = _OCT_YDL;
    }



    // ------------
    //    Events   
    // ------------

    /// @notice Emitted during pullFromLocker() and pullFromLockerPartial() and _forwardYield() [via forwardYield()].
    /// @param  amountBurned Amount of liquidity tokens burned.
    /// @param  claimedZVE Amount of ZVE claimed.
    /// @param  claimedPairAsset Amount of pairAsset claimed.
    event LiquidityTokensBurned(uint256 amountBurned, uint256 claimedZVE, uint256 claimedPairAsset);

    /// @notice Emitted during pushToLockerMulti().
    /// @param  amountMinted Amount of liquidity tokens minted.
    /// @param  depositedZVE Amount of ZVE deposited.
    /// @param  depositedPairAsset Amount of pairAsset deposited.
    event LiquidityTokensMinted(uint256 amountMinted, uint256 depositedZVE, uint256 depositedPairAsset);

    /// @notice Emitted during updateCompoundingRateBIPS().
    /// @param  oldValue The old value of compoundingRateBIPS.
    /// @param  newValue The new value of compoundingRateBIPS.
    event UpdatedCompoundingRateBIPS(uint256 oldValue, uint256 newValue);

    /// @notice Emitted during updateOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    /// @notice Emitted during forwardYield().
    /// @param  asset The "asset" being distributed.
    /// @param  amount The amount distributed.
    event YieldForwarded(address indexed asset, uint256 amount);



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLockerMulti().
    function canPushMulti() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice This pulls capital from the DAO and adds liquidity into a $ZVE/pairAsset pool.
    /// @param  assets The assets to pull from the DAO.
    /// @param  amounts The amount to pull of each asset respectively.
    /// @param  data Accompanying transaction data.
    function pushToLockerMulti(
        address[] calldata assets, uint256[] calldata amounts, bytes[] calldata data
    ) external override onlyOwner nonReentrant {
        address ZVE = IZivoeGlobals_OCL_ZVE(GBL).ZVE();
        require(
            assets[0] == pairAsset && assets[1] == ZVE,
            "OCL_ZVE::pushToLockerMulti() assets[0] != pairAsset || assets[1] != ZVE"
        );

        for (uint256 i = 0; i < 2; i++) {
            require(amounts[i] >= 10 * 10**6, "OCL_ZVE::pushToLockerMulti() amounts[i] < 10 * 10**6");
            IERC20(assets[i]).safeTransferFrom(owner(), address(this), amounts[i]);
        }

        if (nextYieldDistribution == 0) { nextYieldDistribution = block.timestamp + 30 days; }

        uint256 preBasis;
        if (basis != 0) { (preBasis,) = fetchBasis(); }

        // Router addLiquidity() endpoint.
        uint balPairAsset = IERC20(pairAsset).balanceOf(address(this));
        uint balZVE = IERC20(ZVE).balanceOf(address(this));
        IERC20(pairAsset).safeIncreaseAllowance(router, balPairAsset);
        IERC20(ZVE).safeIncreaseAllowance(router, balZVE);

        // Prevent volatility of greater than 10% in pool relative to amounts present.
        (uint256 depositedPairAsset, uint256 depositedZVE, uint256 minted) = IRouter_OCL_ZVE(router).addLiquidity(
            pairAsset, 
            ZVE, 
            balPairAsset,
            balZVE, 
            (balPairAsset * 9) / 10,
            (balZVE * 9) / 10, 
            address(this), block.timestamp + 14 days
        );
        emit LiquidityTokensMinted(minted, depositedZVE, depositedPairAsset);

        if (IERC20(pairAsset).allowance(address(this), router) > 0) {
            IERC20(pairAsset).safeDecreaseAllowance(router, IERC20(pairAsset).allowance(address(this), router));
        }
        if (IERC20(pairAsset).balanceOf(address(this)) > 0) {
            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
        }

        if (IERC20(ZVE).allowance(address(this), router) > 0) {
            IERC20(ZVE).safeDecreaseAllowance(router, IERC20(ZVE).allowance(address(this), router));
        }
        if (IERC20(ZVE).balanceOf(address(this)) > 0) {
            IERC20(ZVE).safeTransfer(owner(), IERC20(ZVE).balanceOf(address(this)));
        }

        // Increase basis by difference.
        (uint256 postBasis,) = fetchBasis();
        require(postBasis > preBasis, "OCL_ZVE::pushToLockerMulti() postBasis <= preBasis");
        basis += postBasis - preBasis;
    }

    /// @notice This burns LP tokens from the $ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    /// @param  data Accompanying transaction data.
    function pullFromLocker(address asset, bytes calldata data) external override onlyOwner nonReentrant {
        address ZVE = IZivoeGlobals_OCL_ZVE(GBL).ZVE();
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, ZVE);
        
        (uint amountAMin, uint amountBMin) = abi.decode(data, (uint, uint));

        // "pair" represents the liquidity pool token (minted, burned).
        // "pairAsset" represents the stablecoin paired against $ZVE.
        if (asset == pair) {
            uint256 preBalLPToken = IERC20(pair).balanceOf(address(this));
            IERC20(pair).safeIncreaseAllowance(router, preBalLPToken);

            // Router removeLiquidity() endpoint.
            (uint256 claimedPairAsset, uint256 claimedZVE) = IRouter_OCL_ZVE(router).removeLiquidity(
                pairAsset, ZVE, preBalLPToken, 
                amountAMin, amountBMin, address(this), block.timestamp + 14 days
            );
            emit LiquidityTokensBurned(preBalLPToken, claimedZVE, claimedPairAsset);
            assert(IERC20(pair).allowance(address(this), router) == 0);

            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(ZVE).safeTransfer(owner(), IERC20(ZVE).balanceOf(address(this)));
            basis = 0;
        }
        else {
            IERC20(asset).safeTransfer(owner(), IERC20(asset).balanceOf(address(this)));
        }
    }

    /// @notice This burns LP tokens from the $ZVE/pairAsset pool and returns them to the DAO.
    /// @param  asset The asset to burn.
    /// @param  amount The amount of "asset" to burn.
    /// @param  data Accompanying transaction data.
    function pullFromLockerPartial(
        address asset, uint256 amount, bytes calldata data
    ) external override onlyOwner nonReentrant {
        address ZVE = IZivoeGlobals_OCL_ZVE(GBL).ZVE();
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, ZVE);
        
        (uint amountAMin, uint amountBMin) = abi.decode(data, (uint, uint));

        // "pair" represents the liquidity pool token (minted, burned).
        // "pairAsset" represents the stablecoin paired against $ZVE.
        if (asset == pair) {
            (uint256 preBasis,) = fetchBasis();
            IERC20(pair).safeIncreaseAllowance(router, amount);

            // Router removeLiquidity() endpoint.
            (uint256 claimedPairAsset, uint256 claimedZVE) = IRouter_OCL_ZVE(router).removeLiquidity(
                pairAsset, ZVE, amount, 
                amountAMin, amountBMin, address(this), block.timestamp + 14 days
            );
            emit LiquidityTokensBurned(amount, claimedZVE, claimedPairAsset);
            assert(IERC20(pair).allowance(address(this), router) == 0);
            
            IERC20(pairAsset).safeTransfer(owner(), IERC20(pairAsset).balanceOf(address(this)));
            IERC20(ZVE).safeTransfer(owner(), IERC20(ZVE).balanceOf(address(this)));
            (uint256 postBasis,) = fetchBasis();
            require(postBasis < preBasis, "OCL_ZVE::pullFromLockerPartial() postBasis >= preBasis");
            basis -= preBasis - postBasis;
        }
        else {
            IERC20(asset).safeTransfer(owner(), amount);
        }
    }

    /// @notice This forwards yield in excess of the basis.
    function forwardYield() external {
        if (IZivoeGlobals_OCL_ZVE(GBL).isKeeper(_msgSender())) {
            require(
                block.timestamp > nextYieldDistribution - 12 hours, 
                "OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution - 12 hours"
            );
        }
        else {
            require(
                block.timestamp > nextYieldDistribution, 
                "OCL_ZVE::forwardYield() block.timestamp <= nextYieldDistribution"
            );
        }

        (uint256 amount, uint256 lp) = fetchBasis();
        if (amount > basis) { _forwardYield(amount, lp); }
        (basis,) = fetchBasis();
        nextYieldDistribution = block.timestamp + 30 days;
    }

    /// @notice This forwards yield to the YDL in the form of pairAsset.
    /// @dev    Private function, only callable via forwardYield().
    /// @param  amount Current pairAsset harvestable.
    /// @param  lp Current ZVE/pairAsset LP tokens.
    function _forwardYield(uint256 amount, uint256 lp) private nonReentrant {
        address ZVE = IZivoeGlobals_OCL_ZVE(GBL).ZVE();
        uint256 lpBurnable = (amount - basis) * lp * (BIPS - compoundingRateBIPS) / amount / BIPS;
        address pair = IFactory_OCL_ZVE(factory).getPair(pairAsset, ZVE);
        IERC20(pair).safeIncreaseAllowance(router, lpBurnable);
        (uint256 claimedPairAsset, uint256 claimedZVE) = IRouter_OCL_ZVE(router).removeLiquidity(
            pairAsset, ZVE, lpBurnable, 0, 0, address(this), block.timestamp + 14 days
        );
        emit LiquidityTokensBurned(lpBurnable, claimedZVE, claimedPairAsset);
        assert(IERC20(pair).allowance(address(this), router) == 0);
        uint balPairAsset = IERC20(pairAsset).balanceOf(address(this));
        emit YieldForwarded(pairAsset, balPairAsset);
        if (pairAsset != IZivoeYDL_OCL_ZVE(IZivoeGlobals_OCL_ZVE(GBL).YDL()).distributedAsset()) {
            IERC20(pairAsset).safeTransfer(OCT_YDL, balPairAsset);
        }
        else {
            IERC20(pairAsset).safeTransfer(IZivoeGlobals_OCL_ZVE(GBL).YDL(), balPairAsset);
        }
        IERC20(ZVE).safeTransfer(owner(), IERC20(ZVE).balanceOf(address(this)));
    }

    /// @notice Returns amount of pairAsset redeemable with current LP position.
    /// @dev    The withdrawal mechanism is ZVE/pairAsset_LP => pairAsset.
    /// @return amount Current pairAsset harvestable.
    /// @return lp Current ZVE/pairAsset LP tokens.
    function fetchBasis() public view returns (uint256 amount, uint256 lp) {
        address pool = IFactory_OCL_ZVE(factory).getPair(pairAsset, IZivoeGlobals_OCL_ZVE(GBL).ZVE());
        uint256 pairAssetBalance = IERC20(pairAsset).balanceOf(pool);
        uint256 poolTotalSupply = IERC20(pool).totalSupply();
        lp = IERC20(pool).balanceOf(address(this));
        amount = lp * pairAssetBalance / poolTotalSupply;
    }

    /// @notice Updates the compounding rate of this contract.
    /// @dev    A value of 2,000 represent 20% of the earnings stays in this contract, compounding.
    /// @param  _compoundingRateBIPS The new compounding rate value.
    function updateCompoundingRateBIPS(uint256 _compoundingRateBIPS) external {
        require(
            _msgSender() == IZivoeGlobals_OCL_ZVE(GBL).TLC(), 
            "OCL_ZVE::updateCompoundingRateBIPS() _msgSender() != IZivoeGlobals_OCL_ZVE(GBL).TLC()"
        );
        require(_compoundingRateBIPS <= BIPS, "OCL_ZVE::updateCompoundingRateBIPS() ratio > BIPS");

        emit UpdatedCompoundingRateBIPS(compoundingRateBIPS, _compoundingRateBIPS);
        compoundingRateBIPS = _compoundingRateBIPS;
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function updateOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCL_ZVE(GBL).ZVL(), 
            "OCL_ZVE::updateOCTYDL() _msgSender() != IZivoeGlobals_OCL_ZVE(GBL).ZVL()"
        );
        require(_OCT_YDL != address(0), "OCL_ZVE::updateOCTYDL() _OCT_YDL == address(0)");
        emit UpdatedOCTYDL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }
    
}