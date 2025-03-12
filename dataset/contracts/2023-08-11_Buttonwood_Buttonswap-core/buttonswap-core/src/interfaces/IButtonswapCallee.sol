// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

interface IButtonswapCallee {
    /**
     * @notice This method is called during {ButtonswapPair-swap} if calldata is supplied.
     * This allows the swap output destination to be a contract that then acts upon receipt of the tokens.
     * @param sender The account that initiated the swap
     * @param amount0 The amount of `token0` that was sent to output destination
     * @param amount1 The amount of `token1` that was sent to output destination
     * @param data The calldata that instructs the destination contract how to respond to the swap
     */
    function buttonswapCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
