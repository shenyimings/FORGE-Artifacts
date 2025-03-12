// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./ISwapper.sol";

interface IDepositSwap {
    /**
     * @notice Swaps tokens input tokens based on provided swap info and
     * deposits swapped tokens into the smart vault.
     *
     * When sent eth, it will wrap it into WETH. After wrapping, WETH can be swapped
     * if it is included in inTokens parameter.
     * @dev Unswapped tokens are transferred back to the caller.
     * Requirements:
     * - caller must set approval for this contract on input tokens in input amount
     * @param inTokens Input tokens to be swapped.
     * @param inAmounts Maximal amount of input tokens to be swapped.
     * @param swapInfo Information needed to perform the swap.
     * @param smartVault Smart vault into which to deposit swapped tokens.
     * @param receiver Receiver of the deposit NFT.
     * @return depositNftId ID of the minted deposit NFT.
     */
    function swapAndDeposit(
        address[] calldata inTokens,
        uint256[] calldata inAmounts,
        SwapInfo[] calldata swapInfo,
        address smartVault,
        address receiver
    ) external payable returns (uint256 depositNftId);
}
