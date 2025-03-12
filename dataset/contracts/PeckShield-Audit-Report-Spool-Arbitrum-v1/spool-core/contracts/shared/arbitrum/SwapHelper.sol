// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.11;

import "./SwapHelperUniswap.sol";
import "./../SwapHelperBalancer.sol";

/// @title Contains logic facilitating swapping using Uniswap / Balancer
abstract contract SwapHelper is SwapHelperBalancer, SwapHelperUniswap {
    using BytesLib for bytes;

    /**
     * @notice Sets initial values
     */
    constructor(Protocol _protocol)
        SwapHelperUniswap(
            _protocol==Protocol.UNISWAP ? 
                ISwapRouter02(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45) : 
                ISwapRouter02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506), 
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
            _protocol)
        SwapHelperBalancer()
    {}

    /**
     * @notice Approve reward token and swap the `amount` to a strategy underlying asset
     * @param from Token to swap from
     * @param to Token to swap to
     * @param amount Amount of tokens to swap
     * @param swapData Swap details showing the path of the swap
     * @return result Amount of underlying (`to`) tokens recieved
     */
    function _approveAndSwap(
        IERC20 from,
        IERC20 to,
        uint256 amount,
        SwapData calldata swapData
    ) internal virtual returns (uint256) {
        // If first byte is les or equal to 6, we swap via the Uniswap
        if (swapData.path.toUint8(0) <= 6) {
            return _approveAndSwapUniswap(from, to, amount, swapData);
        }
        return _approveAndSwapBalancer(from, to, amount, swapData);
    }
}
