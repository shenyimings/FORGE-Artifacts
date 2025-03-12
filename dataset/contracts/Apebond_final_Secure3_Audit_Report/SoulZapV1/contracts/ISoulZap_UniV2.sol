// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISoulAccessManaged} from "./access/ISoulAccessManaged.sol";
import {ISoulFeeManager} from "./fee-manager/ISoulFeeManager.sol";
import {ITransferHelper} from "./utils/ITransferHelper.sol";
import {IEpochVolumeTracker} from "./utils/IEpochVolumeTracker.sol";

interface ISoulZap_UniV2 is ISoulAccessManaged, ITransferHelper, IEpochVolumeTracker {
    /// -----------------------------------------------------------------------
    /// Swap Path
    /// -----------------------------------------------------------------------

    enum SwapType {
        V2
    }

    struct SwapPath {
        address swapRouter;
        SwapType swapType;
        address[] path;
        uint256 amountOutMin;
    }

    //// -----------------------------------------------------------------------
    /// Liquidity Path
    /// -----------------------------------------------------------------------

    enum LPType {
        V2
    }

    struct LiquidityPath {
        address lpRouter;
        LPType lpType;
        uint256 minAmountLP0;
        uint256 minAmountLP1;
    }

    /// -----------------------------------------------------------------------
    /// Swap Params
    /// -----------------------------------------------------------------------

    struct SwapParams {
        IERC20 tokenIn;
        uint256 amountIn;
        address tokenOut;
        SwapPath path;
        address to;
        uint256 deadline;
    }

    /// -----------------------------------------------------------------------
    /// Zap Params
    /// -----------------------------------------------------------------------

    struct ZapParams {
        IERC20 tokenIn;
        uint256 amountIn;
        address token0;
        address token1;
        SwapPath path0;
        SwapPath path1;
        LiquidityPath liquidityPath;
        address to;
        uint256 deadline;
    }

    /// -----------------------------------------------------------------------
    /// Storage Variables
    /// -----------------------------------------------------------------------

    function soulFeeManager() external view returns (ISoulFeeManager);

    /// -----------------------------------------------------------------------
    /// Functions
    /// -----------------------------------------------------------------------

    function swap(SwapParams memory swapParams, SwapPath memory feeSwapPath) external payable;

    function zap(ZapParams memory zapParams, SwapPath memory feeSwapPath) external payable;

    /// -----------------------------------------------------------------------
    /// Fee Management
    /// -----------------------------------------------------------------------

    function isFeeToken(address _token) external view returns (bool valid);

    function getFeeInfo()
        external
        view
        returns (
            address[] memory feeTokens,
            uint256 currentFeePercentage,
            uint256 feeDenominator,
            address feeCollector
        );
}
