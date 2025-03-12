// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function burnFrom(address account, uint256 amount) external;

    event Transfer(address indexed from, address indexed to, uint256 value);
}
