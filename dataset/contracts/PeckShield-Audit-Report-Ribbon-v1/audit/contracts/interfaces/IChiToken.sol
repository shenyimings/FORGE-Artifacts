// SPDX-License-Identifier: MIT
pragma solidity >=0.7.2;

interface IChiToken {
    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function mint(uint256 value) external;

    function free(uint256 value) external returns (uint256);

    function freeUpTo(uint256 value) external returns (uint256);

    function freeFrom(address from, uint256 value) external returns (uint256);

    function freeFromUpTo(address from, uint256 value)
        external
        returns (uint256);
}
