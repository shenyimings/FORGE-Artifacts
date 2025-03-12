// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {ILido} from "../interfaces/lido/ILido.sol";
import {IwstETH} from "../interfaces/lido/IwstETH.sol";
import {ICurvePool} from "../interfaces/curve/ICurvePool.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";

import {AmountReceivedBelowMin} from "../errors/scErrors.sol";
import {ISwapRouter} from "../interfaces/uniswap/ISwapRouter.sol";
import {Constants as C} from "../lib/Constants.sol";

/**
 * @title Swapper
 * @notice Contract facilitating token swaps on Uniswap V3 and 0x.
 */
contract Swapper {
    using SafeTransferLib for ERC20;
    using Address for address;

    // Uniswap V3 router
    ISwapRouter public constant swapRouter = ISwapRouter(C.UNISWAP_V3_SWAP_ROUTER);

    // 0x router address
    address public constant zeroExRouter = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF;

    ICurvePool public constant curvePool = ICurvePool(C.CURVE_ETH_STETH_POOL);

    WETH public constant weth = WETH(payable(C.WETH));
    ILido public constant stEth = ILido(C.STETH);
    IwstETH public constant wstETH = IwstETH(C.WSTETH);

    /**
     * @notice Swap tokens on Uniswap V3 using exact input single function.
     * @param _tokenIn Address of the token to swap.
     * @param _tokenOut Address of the token to receive.
     * @param _amountIn Amount of the token to swap.
     * @param _amountOutMin Minimum amount of the token to receive.
     */
    function uniswapSwapExactInput(
        ERC20 _tokenIn,
        ERC20 _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        uint24 _poolFee
    ) external returns (uint256) {
        ERC20(_tokenIn).safeApprove(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(_tokenIn),
            tokenOut: address(_tokenOut),
            fee: _poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin,
            sqrtPriceLimitX96: 0
        });

        return swapRouter.exactInputSingle(params);
    }

    /**
     * @notice Swap tokens on Uniswap V3 using exact output single function.
     * @param _tokenIn Address of the token to swap.
     * @param _tokenOut Address of the token to receive.
     * @param _amountOut Amount of the token to receive.
     * @param _amountInMaximum Maximum amount of the token to swap.
     */
    function uniswapSwapExactOutput(
        ERC20 _tokenIn,
        ERC20 _tokenOut,
        uint256 _amountOut,
        uint256 _amountInMaximum,
        uint24 _poolFee
    ) external returns (uint256) {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter.ExactOutputSingleParams({
            tokenIn: address(_tokenIn),
            tokenOut: address(_tokenOut),
            fee: _poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountOut: _amountOut,
            amountInMaximum: _amountInMaximum,
            sqrtPriceLimitX96: 0
        });

        _tokenIn.safeApprove(address(swapRouter), _amountInMaximum);

        uint256 amountIn = swapRouter.exactOutputSingle(params);

        _tokenIn.safeApprove(address(swapRouter), 0);

        return amountIn;
    }

    /**
     * @notice Swap tokens on 0x protocol.
     * @param _tokenIn Address of the token to swap.
     * @param _tokenOut Address of the token to receive.
     * @param _amountIn Amount of the token to swap.
     * @param _amountOutMin Minimum amount of the token to receive.
     * @param _swapData Encoded swap data obtained from 0x API.
     */
    function zeroExSwap(
        ERC20 _tokenIn,
        ERC20 _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        bytes calldata _swapData
    ) external returns (uint256) {
        uint256 tokenOutInitialBalance = _tokenOut.balanceOf(address(this));

        _tokenIn.safeApprove(zeroExRouter, _amountIn);

        zeroExRouter.functionCall(_swapData);

        uint256 amountReceived = _tokenOut.balanceOf(address(this)) - tokenOutInitialBalance;

        if (amountReceived < _amountOutMin) revert AmountReceivedBelowMin();

        _tokenIn.approve(zeroExRouter, 0);

        return amountReceived;
    }

    function lidoSwapWethToWstEth(uint256 _wethAmount) external {
        // weth to eth
        weth.withdraw(_wethAmount);

        // stake to lido / eth => stETH
        stEth.submit{value: _wethAmount}(address(0x00));

        //  stETH to wstEth
        uint256 stEthBalance = stEth.balanceOf(address(this));
        ERC20(address(stEth)).safeApprove(address(wstETH), stEthBalance);

        wstETH.wrap(stEthBalance);
    }

    function curveSwapStEthToWeth(uint256 _stEthAmount, uint256 _wethAmountOutMin)
        external
        returns (uint256 wethReceived)
    {
        // stETH to eth
        ERC20(address(stEth)).safeApprove(address(curvePool), _stEthAmount);

        wethReceived = curvePool.exchange(1, 0, _stEthAmount, _wethAmountOutMin);

        // eth to weth
        weth.deposit{value: address(this).balance}();
    }
}
