// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/**
 * Interface which is a face for Dex handlers implementations. On each chain we might use different
 * dex to swap tokens so we need to abstract generic interface.
 */

interface IDex {
    function swap(uint256 _amountIn, address _in, address _out, address _to) external returns (uint[] memory amounts);
    function swapSlippageMin(uint256 _amountIn, uint256 _amountOutMin, address _in, address _out, address _to) external returns (uint[] memory amounts);
    function setRoutes(address[][] memory _routes) external;
    function deleteRoutes(address[][] memory _routes) external;
    function getRoute(address _in, address _out) external view returns (address[] memory route);
    function swapPreview(uint256 _amountIn, address _in, address _out) external view returns (uint amountOut);
}
