// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./IBalancer.sol";

interface IRouter {

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    error InsufficientSharesMinted(uint minted, uint minAmount);
    error InsufficientTokenRedeemed(address token, uint amount, uint minAmount);
    error SwapAmountExceedsBalance(uint amountIn, uint totalSwapAmount);
    error IncorrectDepositAmount(uint has, uint wants);
    error IncorrectSwapToken(address tokenIn, address swapToken);
    error Expired(uint deadline);

    function invest(
        address adapter,
        address balancer,
        address tokenIn,
        uint256 amountIn,
        uint256 minShareAmount,
        IBalancer.SwapInfo[] calldata swaps,
        uint32 deadline
    ) external payable returns (uint sharesAdded);

    function redeem(
        address balancer,
        uint shares, 
        IAdapter targetAdapter, 
        address receiver,
        TokenAmount[] memory minAmounts,
        uint32 deadline
    ) external returns (address[] memory tokens, uint[] memory amounts);

}