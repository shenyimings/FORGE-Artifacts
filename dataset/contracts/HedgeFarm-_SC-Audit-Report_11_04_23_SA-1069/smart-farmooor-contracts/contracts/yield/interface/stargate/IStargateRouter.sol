// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

pragma abicoder v2;

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    /**
     * adds liquidity to router pool and get LP tokens in return  
     */
    function addLiquidity(uint256 poolId, uint256 amount, address to) external;

    /**
     * exit pool by using your LP tokens to withdraw yur liquidity
     */
    function instantRedeemLocal(uint16 poolId, uint256 amountLp, address to) external returns (uint256);

    function redeemLocal(
        uint16 dstChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address payable refundAddress,
        uint256 amountLP,
        bytes calldata to,
        lzTxObj memory lzTxParams
    ) external payable;
}