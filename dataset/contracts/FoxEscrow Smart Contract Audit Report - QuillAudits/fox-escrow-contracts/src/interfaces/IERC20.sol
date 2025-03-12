// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

interface IERC20 {
    function balanceOf(address _holder) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
