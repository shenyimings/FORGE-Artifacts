// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "../ISwapPlace.sol";

contract MockSwapPlace is ISwapPlace {


    function swapPlaceType() external override pure returns (string memory) {
        return "MockSwapPlace";
    }

    function swap(
        SwapRoute calldata route
    ) external override returns (uint256){
        require(false, "swap() not implemented");
        return 0;
    }


    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address pool
    ) external override view returns (uint256){

        if (pool == address(0x1111111111111111111111111111111111111111)) {
            return amountIn * (100 - amountIn / 100) / 100 - 1;
            //            return amountIn * 999 / 1000;
        }

        if (pool == address(0x2222222222222222222222222222222222222222)) {
            return amountIn * (99 - amountIn / 100) / 100 + 2;
            //            return amountIn * 998 / 1000;
        }

        if (pool == address(0x3333333333333333333333333333333333333333)) {
            return amountIn * (98 - amountIn / 100) / 100 + 3;
            //            return amountIn * 997 / 1000;
        }

        return amountIn;
    }


}
