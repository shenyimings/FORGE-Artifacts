// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";

import "./BasicSpell.sol";
import "../interfaces/IWIchiFarm.sol";
import "../interfaces/ichi/IICHIVault.sol";

/**
 * @title IchiSpell
 * @author BlueberryProtocol
 * @notice IchiSpell is the factory contract that
 * defines how Blueberry Protocol interacts with Ichi Vaults
 */
contract IchiSpell is BasicSpell, IUniswapV3SwapCallback {
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev temperory state used to store uni v3 pool when swapping on uni v3
    IUniswapV3Pool private SWAP_POOL;

    /// @dev address of ICHI farm wrapper
    IWIchiFarm public wIchiFarm;
    /// @dev address of ICHI token
    address public ICHI;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        IBank bank_,
        address werc20_,
        address weth_,
        address wichiFarm_
    ) external initializer {
        __BasicSpell_init(bank_, werc20_, weth_);
        if (address(wichiFarm_) == address(0)) revert Errors.ZERO_ADDRESS();

        wIchiFarm = IWIchiFarm(wichiFarm_);
        ICHI = address(wIchiFarm.ICHI());
        IWIchiFarm(wichiFarm_).setApprovalForAll(address(bank_), true);
    }

    /**
     * @notice Internal function to deposit assets on ICHI Vault
     * @dev Deposit isolated underlying to Blueberry Money Market,
     *      Borrow tokens from Blueberry Money Market,
     *      Then deposit borrowed tokens on ICHI vault
     */
    function _deposit(OpenPosParam calldata param) internal {
        Strategy memory strategy = strategies[param.strategyId];

        // 1. Deposit isolated collaterals on Blueberry Money Market
        _doLend(param.collToken, param.collAmount);

        // 2. Borrow specific amounts
        IICHIVault vault = IICHIVault(strategy.vault);
        if (
            vault.token0() != param.borrowToken &&
            vault.token1() != param.borrowToken
        ) revert Errors.INCORRECT_DEBT(param.borrowToken);
        uint256 borrowBalance = _doBorrow(
            param.borrowToken,
            param.borrowAmount
        );

        // 3. Add liquidity - Deposit on ICHI Vault
        bool isTokenA = vault.token0() == param.borrowToken;
        _ensureApprove(param.borrowToken, address(vault), borrowBalance);

        uint ichiVaultShare;
        if (isTokenA) {
            ichiVaultShare = vault.deposit(borrowBalance, 0, address(this));
        } else {
            ichiVaultShare = vault.deposit(0, borrowBalance, address(this));
        }

        // 4. Validate MAX LTV
        _validateMaxLTV(param.strategyId);

        // 5. Validate Max Pos Size
        uint256 lpPrice = bank.oracle().getPrice(address(vault));
        uint256 curPosSize = (lpPrice * ichiVaultShare) /
            10 ** vault.decimals();
        if (curPosSize > strategy.maxPositionSize)
            revert Errors.EXCEED_MAX_POS_SIZE(param.strategyId);
    }

    /**
     * @notice External function to deposit assets on IchiVault
     */
    function openPosition(
        OpenPosParam calldata param
    )
        external
        existingStrategy(param.strategyId)
        existingCollateral(param.strategyId, param.collToken)
    {
        // 1-3 Deposit on ichi vault
        _deposit(param);

        // 4. Put collateral - ICHI Vault Lp Token
        address vault = strategies[param.strategyId].vault;
        _doPutCollateral(vault, IERC20(vault).balanceOf(address(this)));
    }

    /**
     * @notice External function to deposit assets on IchiVault and farm in Ichi Farm
     */
    function openPositionFarm(
        OpenPosParam calldata param
    )
        external
        existingStrategy(param.strategyId)
        existingCollateral(param.strategyId, param.collToken)
    {
        Strategy memory strategy = strategies[param.strategyId];
        address lpToken = wIchiFarm.ichiFarm().lpToken(param.farmingPid);
        if (strategy.vault != lpToken) revert Errors.INCORRECT_LP(lpToken);

        // 1-3 Deposit on ichi vault
        _deposit(param);

        // 4. Take out collateral
        IBank.Position memory pos = bank.getCurrentPositionInfo();
        address posCollToken = pos.collToken;
        uint256 collId = pos.collId;
        uint256 collSize = pos.collateralSize;
        if (collSize > 0) {
            (uint256 decodedPid, ) = wIchiFarm.decodeId(collId);
            if (param.farmingPid != decodedPid)
                revert Errors.INCORRECT_PID(param.farmingPid);
            if (posCollToken != address(wIchiFarm))
                revert Errors.INCORRECT_COLTOKEN(posCollToken);
            bank.takeCollateral(collSize);
            wIchiFarm.burn(collId, collSize);
            _doRefund(ICHI);
        }

        // 5. Deposit on farming pool, put collateral
        uint256 lpAmount = IERC20(lpToken).balanceOf(address(this));
        _ensureApprove(lpToken, address(wIchiFarm), lpAmount);
        uint256 id = wIchiFarm.mint(param.farmingPid, lpAmount);
        bank.putCollateral(address(wIchiFarm), id, lpAmount);
    }

    /**
     * @notice Increase isolated collateral to support the position
     * @param token Isolated collateral token address
     * @param amount Amount of token to increase position
     */
    function increasePosition(address token, uint256 amount) external {
        // 1. Deposit isolated collaterals on Blueberry Money Market
        _doLend(token, amount);
    }

    /**
     * @dev Reduce isolated collateral of position
     * @param collToken Isolated collateral token address
     * @param collShareAmount Amount of Isolated collateral
     */
    function reducePosition(
        uint256 strategyId,
        address collToken,
        uint256 collShareAmount
    ) external {
        // Validate strategy id
        IBank.Position memory pos = bank.getCurrentPositionInfo();
        address unwrappedCollToken = IERC20Wrapper(pos.collToken)
            .getUnderlyingToken(pos.collId);
        if (strategies[strategyId].vault != unwrappedCollToken)
            revert Errors.INCORRECT_STRATEGY_ID(strategyId);

        _doWithdraw(collToken, collShareAmount);
        _doRefund(collToken);
        _validateMaxLTV(strategyId);
    }

    /**
     * @notice Internal function to withdraw assets from ICHI Vault
     * @dev Withdraw assets from ICHI Vault,
     *      Swap withdrawn assets to debt token,
     *      Withdraw isolated collaterals from Blueberry Money Market,
     *      Repay Debt and refund rest to user
     */
    function _withdraw(ClosePosParam calldata param) internal {
        if (param.sellSlippage > bank.config().maxSlippageOfClose())
            revert Errors.RATIO_TOO_HIGH(param.sellSlippage);

        Strategy memory strategy = strategies[param.strategyId];
        IICHIVault vault = IICHIVault(strategy.vault);
        uint256 positionId = bank.POSITION_ID();

        // 1. Compute repay amount if MAX_INT is supplied (max debt)
        uint256 amountRepay = param.amountRepay;
        if (amountRepay == type(uint256).max) {
            amountRepay = bank.currentPositionDebt(positionId);
        }

        // 2. Calculate actual amount to remove
        uint256 amountPosRemove = param.amountPosRemove;
        if (amountPosRemove == type(uint256).max) {
            amountPosRemove = vault.balanceOf(address(this));
        }

        // 3. Withdraw liquidity from ICHI vault
        vault.withdraw(amountPosRemove, address(this));

        // 4. Swap withdrawn tokens to initial deposit token
        bool isTokenA = vault.token0() == param.borrowToken;
        uint256 amountToSwap = IERC20(
            isTokenA ? vault.token1() : vault.token0()
        ).balanceOf(address(this));

        if (amountToSwap > 0) {
            SWAP_POOL = IUniswapV3Pool(vault.pool());
            uint160 deltaSqrt = (param.sqrtRatioLimit *
                uint160(param.sellSlippage)) / uint160(Constants.DENOMINATOR);
            SWAP_POOL.swap(
                address(this),
                // if withdraw token is Token0, then swap token1 -> token0 (false)
                !isTokenA,
                amountToSwap.toInt256(),
                isTokenA
                    ? param.sqrtRatioLimit + deltaSqrt
                    : param.sqrtRatioLimit - deltaSqrt, // slippaged price cap
                abi.encode(address(this))
            );
        }

        // 5. Withdraw isolated collateral from Bank
        _doWithdraw(param.collToken, param.amountShareWithdraw);

        // 6. Repay
        _doRepay(param.borrowToken, amountRepay);

        _validateMaxLTV(param.strategyId);

        // 7. Refund
        _doRefund(param.borrowToken);
        _doRefund(param.collToken);
    }

    /**
     * @notice External function to withdraw assets from ICHI Vault
     */
    function closePosition(
        ClosePosParam calldata param
    )
        external
        existingStrategy(param.strategyId)
        existingCollateral(param.strategyId, param.collToken)
    {
        // 1. Take out collateral
        _doTakeCollateral(
            strategies[param.strategyId].vault,
            param.amountPosRemove
        );

        // 2-8. Remove liquidity
        _withdraw(param);
    }

    function closePositionFarm(
        ClosePosParam calldata param
    )
        external
        existingStrategy(param.strategyId)
        existingCollateral(param.strategyId, param.collToken)
    {
        address vault = strategies[param.strategyId].vault;
        IBank.Position memory pos = bank.getCurrentPositionInfo();
        address posCollToken = pos.collToken;
        uint256 collId = pos.collId;
        if (IWIchiFarm(posCollToken).getUnderlyingToken(collId) != vault)
            revert Errors.INCORRECT_UNDERLYING(vault);
        if (posCollToken != address(wIchiFarm))
            revert Errors.INCORRECT_COLTOKEN(posCollToken);

        // 1. Take out collateral
        bank.takeCollateral(param.amountPosRemove);
        wIchiFarm.burn(collId, param.amountPosRemove);
        _doRefundRewards(ICHI);

        // 2-8. Remove liquidity
        _withdraw(param);

        // 9. Refund ichi token
        _doRefund(ICHI);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        if (msg.sender != address(SWAP_POOL))
            revert Errors.NOT_FROM_UNIV3(msg.sender);
        address payer = abi.decode(data, (address));

        if (amount0Delta > 0) {
            if (payer == address(this)) {
                IERC20Upgradeable(SWAP_POOL.token0()).safeTransfer(
                    msg.sender,
                    amount0Delta.toUint256()
                );
            } else {
                IERC20Upgradeable(SWAP_POOL.token0()).safeTransferFrom(
                    payer,
                    msg.sender,
                    amount0Delta.toUint256()
                );
            }
        } else if (amount1Delta > 0) {
            if (payer == address(this)) {
                IERC20Upgradeable(SWAP_POOL.token1()).safeTransfer(
                    msg.sender,
                    amount1Delta.toUint256()
                );
            } else {
                IERC20Upgradeable(SWAP_POOL.token1()).safeTransferFrom(
                    payer,
                    msg.sender,
                    amount1Delta.toUint256()
                );
            }
        }
    }
}
