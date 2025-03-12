// SPDX-License-Identifier: BUSL-1.1
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

/// -----------------------------------------------------------------------
/// Package Imports (alphabetical)
/// -----------------------------------------------------------------------
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// -----------------------------------------------------------------------
/// Local Imports (alphabetical)
/// -----------------------------------------------------------------------
import {Constants} from "../../utils/Constants.sol";
import {ICustomBillRefillable} from "./lib/ICustomBillRefillable.sol";
import {ISoulFeeManager} from "../../fee-manager/ISoulFeeManager.sol";
import {SoulZap_Ext_BondNftWhitelist} from "./SoulZap_Ext_BondNftWhitelist.sol";
import {SoulZap_UniV2} from "../../SoulZap_UniV2.sol";

/**
 * @title SoulZap_Ext_ApeBond
 * @dev This contract extends the SoulZap_UniV2 contract with additional functionality for ApeBond.
 * @author Soul Solidity - Contact for mainnet licensing until 730 days after first deployment transaction with matching bytecode.
 * Otherwise feel free to experiment locally or on testnets.
 * @notice Do not use this contract for any tokens that do not have a standard ERC20 implementation.
 */
abstract contract SoulZap_Ext_ApeBond is SoulZap_Ext_BondNftWhitelist, SoulZap_UniV2 {
    using SafeERC20 for IERC20;

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event ZapBond(ZapParams zapParams, ICustomBillRefillable bond, uint256 maxPrice);

    constructor() {}

    /// -----------------------------------------------------------------------
    /// External Functions
    /// -----------------------------------------------------------------------

    /// @notice Zap single token to ApeBond
    /// @param zapParams ISoulZap.ZapParams
    /// @param bond Treasury bond address
    /// @param maxPrice Max price of treasury bond
    function zapBond(
        ZapParams memory zapParams,
        SwapPath memory feeSwapPath,
        ICustomBillRefillable bond,
        uint256 maxPrice
    ) external payable nonReentrant whenNotPaused verifyMsgValueAndWrap(zapParams.tokenIn, zapParams.amountIn) {
        if (address(zapParams.tokenIn) == address(Constants.NATIVE_ADDRESS)) {
            _zapBond(zapParams, feeSwapPath, bond, maxPrice);
        } else {
            uint256 balanceBefore = _getBalance(zapParams.tokenIn);
            zapParams.tokenIn.safeTransferFrom(msg.sender, address(this), zapParams.amountIn);
            zapParams.amountIn = _getBalance(zapParams.tokenIn) - balanceBefore;
            _zapBond(zapParams, feeSwapPath, bond, maxPrice);
        }
    }

    /// -----------------------------------------------------------------------
    /// Private Functions
    /// -----------------------------------------------------------------------

    function _zapBond(
        ZapParams memory zapParams,
        SwapPath memory feeSwapPath,
        ICustomBillRefillable bond,
        uint256 maxPrice
    ) private {
        IUniswapV2Pair bondPrincipalToken = IUniswapV2Pair(bond.principalToken());
        bool skipFee = isBondNftWhitelisted(bond);

        //Check if bond principal token is single token or lp
        bool isSingleTokenBond = true;
        try IUniswapV2Pair(bondPrincipalToken).token0() returns (address /*_token0*/) {
            isSingleTokenBond = false;
        } catch (bytes memory) {}

        address to;
        if (isSingleTokenBond) {
            SwapParams memory swapParams = SwapParams({
                tokenIn: zapParams.tokenIn,
                amountIn: zapParams.amountIn,
                tokenOut: zapParams.token0,
                path: zapParams.path0,
                to: zapParams.to,
                deadline: zapParams.deadline
            });
            require(swapParams.tokenOut == address(bondPrincipalToken), "ApeBond: Wrong token for Bond");
            to = swapParams.to;
            swapParams.to = address(this);
            _swap(swapParams, feeSwapPath, skipFee);
        } else {
            require(
                (zapParams.token0 == bondPrincipalToken.token0() && zapParams.token1 == bondPrincipalToken.token1()) ||
                    (zapParams.token1 == bondPrincipalToken.token0() &&
                        zapParams.token0 == bondPrincipalToken.token1()),
                "ApeBond: Wrong LP bondPrincipalToken for Bond"
            );
            to = zapParams.to;
            zapParams.to = address(this);
            _zap(zapParams, feeSwapPath, skipFee);
        }

        uint256 balance = bondPrincipalToken.balanceOf(address(this));
        bondPrincipalToken.approve(address(bond), balance);
        bond.deposit(balance, maxPrice, to);
        bondPrincipalToken.approve(address(bond), 0);

        emit ZapBond(zapParams, bond, maxPrice);
    }
}
