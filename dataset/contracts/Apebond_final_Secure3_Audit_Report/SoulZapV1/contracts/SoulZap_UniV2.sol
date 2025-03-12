// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/*
 ██████╗ █████╗ ██╗   ██╗██╗        ██████╗ █████╗ ██╗     ██╗██████╗ ██╗████████╗██╗   ██╗
██╔════╝██╔══██╗██║   ██║██║       ██╔════╝██╔══██╗██║     ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
╚█████╗ ██║  ██║██║   ██║██║       ╚█████╗ ██║  ██║██║     ██║██║  ██║██║   ██║    ╚████╔╝ 
 ╚═══██╗██║  ██║██║   ██║██║        ╚═══██╗██║  ██║██║     ██║██║  ██║██║   ██║     ╚██╔╝  
██████╔╝╚█████╔╝╚██████╔╝███████╗  ██████╔╝╚█████╔╝███████╗██║██████╔╝██║   ██║      ██║   
╚═════╝  ╚════╝  ╚═════╝ ╚══════╝  ╚═════╝  ╚════╝ ╚══════╝╚═╝╚═════╝ ╚═╝   ╚═╝      ╚═╝   

 * Twitter: https://twitter.com/SoulSolidity
 *  GitHub: https://github.com/SoulSolidity
 *     Web: https://SoulSolidity.com
 */

/// -----------------------------------------------------------------------
/// Package Imports (alphabetical)
/// -----------------------------------------------------------------------

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// -----------------------------------------------------------------------
/// Internal Imports (alphabetical)
/// -----------------------------------------------------------------------
import {Constants} from "./utils/Constants.sol";
import {IWETH} from "./lib/IWETH.sol";
import {EpochVolumeTracker} from "./utils/EpochVolumeTracker.sol";
import {ISoulFeeManager} from "./fee-manager/ISoulFeeManager.sol";
import {ISoulZap_UniV2} from "./ISoulZap_UniV2.sol";
import {SoulAccessManaged} from "./access/SoulAccessManaged.sol";
import {TransferHelper} from "./utils/TransferHelper.sol";
import {LocalVarsLib} from "./utils/LocalVarsLib.sol";

/*
/// @dev The receive method is used as a fallback function in a contract
/// and is called when ether is sent to a contract with no calldata.

*/
/**
 * @title SoulZap_UniV2
 * @notice This contract includes functionalities for zapping in and out of UniswapV2 type liquidity pools.
 * @dev Do not use this contract for any tokens that do not have a standard ERC20 implementation.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment
 *   transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 */
contract SoulZap_UniV2 is
    ISoulZap_UniV2,
    SoulAccessManaged,
    EpochVolumeTracker,
    Initializable,
    Pausable,
    ReentrancyGuard,
    TransferHelper
{
    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    ISoulFeeManager public soulFeeManager;

    bytes32 public SOUL_ZAP_PAUSER_ROLE = _getRoleHash("SOUL_ZAP_PAUSER_ROLE");
    bytes32 public SOUL_ZAP_ADMIN_ROLE = _getRoleHash("SOUL_ZAP_ADMIN_ROLE");

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Swap(SwapParams swapParams);
    event Zap(ZapParams zapParams);

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        address _accessRegistry,
        IWETH _wnative,
        ISoulFeeManager _soulFeeManager,
        /// @dev Set to zero to start epoch tracking immediately
        uint256 _epochStartTime
    ) SoulAccessManaged(_accessRegistry) EpochVolumeTracker(0, _epochStartTime) TransferHelper(_wnative) {
        require(_soulFeeManager.isSoulFeeManager(), "SoulZap: soulFeeManager is not ISoulFeeManager");
        soulFeeManager = _soulFeeManager;
    }

    /// @dev The receive method is used as a fallback function in a contract
    /// and is called when ether is sent to a contract with no calldata.
    receive() external payable {
        require(msg.sender == address(WNATIVE), "SoulZap: Only receive from WNATIVE");
    }

    /**
     * @dev This modifier checks if the transaction includes Ether (msg.value > 0).
     * If it does, it ensures that the input token is Wrapped Native (WNATIVE) and the input amount is 0.
     * It then wraps the Ether into WNATIVE and returns the amount of WNATIVE.
     *
     * @param _inputToken The token that the user wants to use for the transaction.
     * @param _inputAmount The amount of the token that the user wants to use for the transaction.
     */
    modifier verifyMsgValueAndWrap(IERC20 _inputToken, uint256 _inputAmount) {
        if (msg.value > 0) {
            require(
                address(_inputToken) == address(Constants.NATIVE_ADDRESS),
                "SoulZap: tokenIn MUST be NATIVE_ADDRESS with msg.value"
            );
            (, uint256 wrappedAmount) = _wrapNative();
            require(_inputAmount == wrappedAmount, "SoulZap: amountIn not equal to wrappedAmount");
        }
        _;
    }

    /// -----------------------------------------------------------------------
    /// Pausing
    /// -----------------------------------------------------------------------

    function pause() external onlyAccessRegistryRole(SOUL_ZAP_PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyAccessRegistryRole(SOUL_ZAP_ADMIN_ROLE) {
        _unpause();
    }

    /// -----------------------------------------------------------------------
    /// Swap Functions
    /// -----------------------------------------------------------------------

    /// @notice Zap single token to LP
    /// @param swapParams all parameters for zap
    /// @param feeSwapPath swap path for protocol fee
    function swap(
        SwapParams memory swapParams,
        SwapPath memory feeSwapPath
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
        verifyMsgValueAndWrap(swapParams.tokenIn, swapParams.amountIn)
    {
        if (address(swapParams.tokenIn) == address(Constants.NATIVE_ADDRESS)) {
            _swap(swapParams, feeSwapPath, true);
        } else {
            // No msg.value
            uint256 balanceBefore = _getBalance(swapParams.tokenIn);
            swapParams.tokenIn.safeTransferFrom(msg.sender, address(this), swapParams.amountIn);
            swapParams.amountIn = _getBalance(swapParams.tokenIn) - balanceBefore;
            _swap(swapParams, feeSwapPath, true);
        }
    }

    /// @notice Ultimate ZAP function
    /// @dev Assumes tokens are already transferred to this contract.
    /// - whenNotPaused: Only works when not paused which also pauses all other extensions which extend this
    /// @param swapParams all parameters for swap
    /// @param feeSwapPath swap path for protocol fee
    function _swap(SwapParams memory swapParams, SwapPath memory feeSwapPath, bool takeFee) internal whenNotPaused {
        // Verify inputs
        require(swapParams.amountIn > 0, "SoulZap: amountIn must be > 0");
        require(swapParams.to != address(0), "SoulZap: Can't swap to null address");
        require(swapParams.tokenOut != address(0), "SoulZap: tokenOut can't be address(0)");
        require(address(swapParams.tokenIn) != swapParams.tokenOut, "SoulZap: tokens can't be the same");

        bool native = address(swapParams.tokenIn) == address(Constants.NATIVE_ADDRESS);
        if (native) swapParams.tokenIn = WNATIVE;

        if (takeFee) {
            swapParams.amountIn -= _handleFee(
                swapParams.tokenIn,
                swapParams.amountIn,
                feeSwapPath,
                swapParams.deadline
            );
        }

        /**
         * Handle token Swap
         */
        require(swapParams.path.swapRouter != address(0), "SoulZap: swap router can not be address(0)");
        require(swapParams.path.path[0] == address(swapParams.tokenIn), "SoulZap: wrong path path[0]");
        require(
            swapParams.path.path[swapParams.path.path.length - 1] == swapParams.tokenOut,
            "SoulZap: wrong path path[-1]"
        );
        swapParams.tokenIn.approve(swapParams.path.swapRouter, swapParams.amountIn);
        _routerSwapFromPath(swapParams.path, swapParams.amountIn, swapParams.to, swapParams.deadline);

        emit Swap(swapParams);
    }

    /// -----------------------------------------------------------------------
    /// Zap Functions
    /// -----------------------------------------------------------------------

    /// @notice Zap single token to LP
    /// @param zapParams parameters for Zap
    /// @param feeSwapPath swap path for protocol fee
    function zap(
        ZapParams memory zapParams,
        SwapPath memory feeSwapPath
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
        verifyMsgValueAndWrap(zapParams.tokenIn, zapParams.amountIn)
    {
        if (address(zapParams.tokenIn) == address(Constants.NATIVE_ADDRESS)) {
            _zap(zapParams, feeSwapPath, true);
        } else {
            uint256 balanceBefore = _getBalance(zapParams.tokenIn);
            zapParams.tokenIn.safeTransferFrom(msg.sender, address(this), zapParams.amountIn);
            zapParams.amountIn = _getBalance(zapParams.tokenIn) - balanceBefore;
            _zap(zapParams, feeSwapPath, true);
        }
    }

    /// @notice Ultimate ZAP function
    /// @dev Assumes tokens are already transferred to this contract.
    /// - whenNotPaused: Only works when not paused which also pauses all other extensions which extend this
    /// - Native input zap MUST be done with Constants.NATIVE_ADDRESS
    /// @param zapParams see ISoulZap_UniV2.ZapParams struct
    /// @param feeSwapPath see ISoulZap_UniV2.SwapPath struct
    function _zap(ZapParams memory zapParams, SwapPath memory feeSwapPath, bool takeFee) internal whenNotPaused {
        // Verify inputs
        require(zapParams.amountIn > 0, "SoulZap: amountIn must be > 0");
        require(zapParams.to != address(0), "SoulZap: Can't zap to null address");
        require(zapParams.liquidityPath.lpRouter != address(0), "SoulZap: lp router can not be address(0)");
        require(zapParams.token0 != address(0), "SoulZap: token0 can not be address(0)");
        require(zapParams.token1 != address(0), "SoulZap: token1 can not be address(0)");

        bool native = address(zapParams.tokenIn) == address(Constants.NATIVE_ADDRESS);
        if (native) zapParams.tokenIn = WNATIVE;

        // Setup struct to prevent stack overflow
        LocalVarsLib.LocalVars memory vars;
        // Ensure token addresses and paths are in ascending numerical order
        if (zapParams.token1 < zapParams.token0) {
            (zapParams.token0, zapParams.token1) = (zapParams.token1, zapParams.token0);
            (zapParams.path0, zapParams.path1) = (zapParams.path1, zapParams.path0);
        }

        if (takeFee) {
            zapParams.amountIn -= _handleFee(zapParams.tokenIn, zapParams.amountIn, feeSwapPath, zapParams.deadline);
        }

        /**
         * Setup swap amount0 and amount1
         */
        if (zapParams.liquidityPath.lpType == LPType.V2) {
            // Handle UniswapV2 Liquidity
            require(
                IUniswapV2Factory(IUniswapV2Router02(zapParams.liquidityPath.lpRouter).factory()).getPair(
                    zapParams.token0,
                    zapParams.token1
                ) != address(0),
                "SoulZap: Pair doesn't exist"
            );
            vars.amount0In = zapParams.amountIn / 2;
            vars.amount1In = zapParams.amountIn / 2;
        } else {
            revert("SoulZap: LPType not supported");
        }

        /**
         * Handle token0 Swap
         */
        if (zapParams.token0 != address(zapParams.tokenIn)) {
            require(zapParams.path0.swapRouter != address(0), "SoulZap: swap router can not be address(0)");
            require(zapParams.path0.path[0] == address(zapParams.tokenIn), "SoulZap: wrong path path0[0]");
            require(
                zapParams.path0.path[zapParams.path0.path.length - 1] == zapParams.token0,
                "SoulZap: wrong path path0[-1]"
            );
            zapParams.tokenIn.approve(zapParams.path0.swapRouter, vars.amount0In);
            vars.amount0Out = _routerSwapFromPath(zapParams.path0, vars.amount0In, address(this), zapParams.deadline);
        } else {
            vars.amount0Out = zapParams.amountIn - vars.amount1In;
        }
        /**
         * Handle token1 Swap
         */
        if (zapParams.token1 != address(zapParams.tokenIn)) {
            require(zapParams.path1.swapRouter != address(0), "SoulZap: swap router can not be address(0)");
            require(zapParams.path1.path[0] == address(zapParams.tokenIn), "SoulZap: wrong path path1[0]");
            require(
                zapParams.path1.path[zapParams.path1.path.length - 1] == zapParams.token1,
                "SoulZap: wrong path path1[-1]"
            );
            zapParams.tokenIn.approve(zapParams.path1.swapRouter, vars.amount1In);
            vars.amount1Out = _routerSwapFromPath(zapParams.path1, vars.amount1In, address(this), zapParams.deadline);
        } else {
            vars.amount1Out = zapParams.amountIn - vars.amount0In;
        }

        /**
         * Handle Liquidity Add
         */
        IERC20(zapParams.token0).approve(address(zapParams.liquidityPath.lpRouter), vars.amount0Out);
        IERC20(zapParams.token1).approve(address(zapParams.liquidityPath.lpRouter), vars.amount1Out);

        if (zapParams.liquidityPath.lpType == LPType.V2) {
            // Add liquidity to UniswapV2 Pool
            (vars.amount0Lp, vars.amount1Lp, ) = IUniswapV2Router02(zapParams.liquidityPath.lpRouter).addLiquidity(
                zapParams.token0,
                zapParams.token1,
                vars.amount0Out,
                vars.amount1Out,
                zapParams.liquidityPath.minAmountLP0,
                zapParams.liquidityPath.minAmountLP1,
                zapParams.to,
                zapParams.deadline
            );
        } else {
            revert("SoulZap: lpType not supported");
        }

        if (zapParams.token0 == address(WNATIVE)) {
            // Ensure WNATIVE is called last
            _transferOut(IERC20(zapParams.token1), vars.amount1Out - vars.amount1Lp, msg.sender, native);
            _transferOut(IERC20(zapParams.token0), vars.amount0Out - vars.amount0Lp, msg.sender, native);
        } else {
            _transferOut(IERC20(zapParams.token0), vars.amount0Out - vars.amount0Lp, msg.sender, native);
            _transferOut(IERC20(zapParams.token1), vars.amount1Out - vars.amount1Lp, msg.sender, native);
        }

        emit Zap(zapParams);
    }

    function _routerSwapFromPath(
        SwapPath memory _uniSwapPath,
        uint256 _amountIn,
        address _to,
        uint256 _deadline
    ) private returns (uint256 amountOut) {
        require(_uniSwapPath.path.length >= 2, "SoulZap: need path0 of >=2");
        address outputToken = _uniSwapPath.path[_uniSwapPath.path.length - 1];
        uint256 balanceBefore = _getBalance(IERC20(outputToken), _to);
        _routerSwap(
            _uniSwapPath.swapRouter,
            _uniSwapPath.swapType,
            _amountIn,
            _uniSwapPath.amountOutMin,
            _uniSwapPath.path,
            _to,
            _deadline
        );
        amountOut = _getBalance(IERC20(outputToken), _to) - balanceBefore;
    }

    function _routerSwap(
        address router,
        SwapType swapType,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address _to,
        uint256 deadline
    ) private {
        if (swapType == SwapType.V2) {
            IUniswapV2Router02(router).swapExactTokensForTokens(amountIn, amountOutMin, path, _to, deadline);
        } else {
            revert("SoulZap: SwapType not supported");
        }
    }

    /// -----------------------------------------------------------------------
    /// Fee functions
    /// -----------------------------------------------------------------------

    /**
     * @notice Checks if a given token is a valid fee token.
     * @dev Calls the soulFeeManager's isFeeToken function to determine if the token is used for fees.
     * @param _token The address of the token to check.
     * @return valid True if the token is a valid fee token, false otherwise.
     */
    function isFeeToken(address _token) external view returns (bool valid) {
        return soulFeeManager.isFeeToken(_token);
    }

    /**
     * @notice Retrieves the current fee information for a given epoch volume.
     * @dev Calls the soulFeeManager's getFeeInfo function with the current epoch volume to get fee details.
     * @return feeTokens An array of addresses representing the fee tokens.
     * @return currentFeePercentage The current fee percentage for the epoch.
     * @return feeDenominator The denominator used to calculate the fee percentage.
     * @return feeCollector The address of the fee collector.
     */
    function getFeeInfo()
        public
        view
        override
        returns (address[] memory feeTokens, uint256 currentFeePercentage, uint256 feeDenominator, address feeCollector)
    {
        (feeTokens, currentFeePercentage, feeDenominator, feeCollector) = soulFeeManager.getFeeInfo(getEpochVolume());
    }

    /**
     * @notice Handles the protocol fee calculation and transfer.
     * @dev This function calculates the protocol fee based on the input amount and the current epoch volume.
     * If the protocol fee is not zero, it checks if the output token from the fee swap path is a valid fee token.
     * If the fee swap path length is greater than or equal to 2, it approves the input token for the swap router
     *   and performs a router swap.
     * If the fee swap path length is less than 2, it transfers out the input token to the fee collector.
     * The function also accumulates the volume based on the output of the swap or the input fee amount.
     * @param _inputToken The input token for which the fee is to be calculated.
     * @param _inputAmount The amount of the input token.
     * @param _feeSwapPath The swap path for the fee.
     * @param _deadline The deadline for the swap to occur.
     * @return inputFeeAmount The calculated fee amount.
     */
    function _handleFee(
        IERC20 _inputToken,
        uint256 _inputAmount,
        SwapPath memory _feeSwapPath,
        uint256 _deadline
    ) private returns (uint256 inputFeeAmount) {
        (, uint256 feePercentage, uint256 feeDenominator, address feeCollector) = getFeeInfo();
        if (feePercentage == 0) {
            return 0;
        }

        inputFeeAmount = (_inputAmount * feePercentage) / feeDenominator;

        if (_feeSwapPath.path.length >= 2) {
            address outputToken = _feeSwapPath.path[_feeSwapPath.path.length - 1];
            require(soulFeeManager.isFeeToken(outputToken), "SoulZap: Invalid output token in feeSwapPath");

            _inputToken.approve(_feeSwapPath.swapRouter, inputFeeAmount);
            uint256 amountOut = _routerSwapFromPath(_feeSwapPath, inputFeeAmount, feeCollector, _deadline);
            _accumulateFeeVolume(amountOut);
        } else {
            /// @dev Input token is considered fee token or a token with no output route
            /// In order to not create a denial of service, we take any input token in this case.
            _transferOut(_inputToken, inputFeeAmount, feeCollector, false);
            // Only increase fee volume if input token is a fee token
            if (soulFeeManager.isFeeToken(address(_inputToken))) {
                _accumulateFeeVolume(inputFeeAmount);
            }
        }
    }
}
