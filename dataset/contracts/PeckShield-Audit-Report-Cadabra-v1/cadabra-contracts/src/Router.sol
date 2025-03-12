// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/utils/Address.sol";

import "./interfaces/IBalancer.sol";
import "./interfaces/IAdapter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IRouter.sol";
import "./helpers/SwapExecutor.sol";

contract Router is IRouter {

    address constant ETH_IDENTIFIER = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address public immutable weth;
    SwapExecutor public immutable swapExecutor;

    constructor(address _weth, address _swapExecutor) {
        weth = _weth;
        swapExecutor = SwapExecutor(_swapExecutor);
    }

    function invest(
        address adapter,
        address balancer,
        address tokenIn,
        uint256 amountIn,
        uint256 minShareAmount,
        IBalancer.SwapInfo[] calldata swaps,
        uint32 deadline
    ) external payable override returns (uint sharesAdded) {
        if (deadline < block.timestamp) {
            revert Expired(deadline);
        }
        if (tokenIn == ETH_IDENTIFIER) {
            if (amountIn != msg.value) {
                revert IncorrectDepositAmount(msg.value, amountIn);
            }
            IWETH(weth).deposit{value: msg.value}();
            tokenIn = weth;
        } else {
            SafeERC20.safeTransferFrom(
                IERC20(tokenIn),
                msg.sender,
                address(this),
                amountIn
            );
        }

        uint256 totalSwapAmount = 0;
        for (uint i = 0; i < swaps.length; i++) {
            IBalancer.SwapInfo memory swap = swaps[i];
            if (swap.token != tokenIn) {
                revert IncorrectSwapToken(tokenIn, swap.token);
            }
            totalSwapAmount += swap.amount;
        }

        if (totalSwapAmount > amountIn) {
            revert SwapAmountExceedsBalance(amountIn, totalSwapAmount);
        }

        SafeERC20.safeTransfer(IERC20(tokenIn), address(swapExecutor), totalSwapAmount);
        swapExecutor.executeSwaps(swaps);

        SafeERC20.safeTransfer(IERC20(tokenIn), adapter, amountIn - totalSwapAmount);

        sharesAdded = IBalancer(balancer).invest(adapter, msg.sender);

        if (sharesAdded < minShareAmount) {
            revert InsufficientSharesMinted(sharesAdded, minShareAmount);
        }
    }

    function redeem(
        address balancer,
        uint shares, 
        IAdapter targetAdapter, 
        address receiver,
        TokenAmount[] memory minAmounts,
        uint32 deadline
    ) external override returns (address[] memory tokens, uint[] memory amounts) 
    {
        if (deadline < block.timestamp) {
            revert Expired(deadline);
        }
        uint256[] memory balancesBefore = new uint256[](minAmounts.length);
        for (uint i = 0; i < minAmounts.length; i++) {
            TokenAmount memory ta = minAmounts[i];
            balancesBefore[i] = IERC20(ta.token).balanceOf(receiver);
        }
        
        SafeERC20.safeTransferFrom(IERC20(balancer), msg.sender, address(this), shares);
        (tokens, amounts) = IBalancer(balancer).redeem(shares, targetAdapter, receiver);

        for (uint i = 0; i < minAmounts.length; i++) {
            TokenAmount memory ta = minAmounts[i];
            uint balanceAfter = IERC20(ta.token).balanceOf(receiver);
            uint diff = balanceAfter - balancesBefore[i];
            if (diff < ta.amount) {
                revert InsufficientTokenRedeemed(ta.token, diff, ta.amount);
            }
        }
    }

}