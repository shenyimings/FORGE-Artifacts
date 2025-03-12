// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

contract MockRouter {
    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        pure
        returns (uint256[] memory amountsOut)
    {
        amountsOut = new uint256[](path.length);
        uint256 amountOut = amountIn;
        for (uint256 i; i < path.length; i++) {
            amountsOut[i] = amountOut;
            amountOut = (amountOut * 998) / 1000;
        }
        amountsOut[amountsOut.length - 1] *= 10**12;
    }
}
