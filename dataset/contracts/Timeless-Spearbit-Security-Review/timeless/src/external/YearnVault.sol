// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface YearnVault {
    function token() external view returns (address);

    function deposit(uint256 amount) external returns (uint256);

    function withdraw(uint256 shareAmount, address recipient)
        external
        returns (uint256);

    function pricePerShare() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function balanceOf(address account) external view returns (uint256);
}
