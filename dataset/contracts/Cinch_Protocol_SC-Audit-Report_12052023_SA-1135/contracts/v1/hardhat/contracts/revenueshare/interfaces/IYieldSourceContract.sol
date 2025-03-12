// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IYieldSourceContract {
    function deposit(uint256 assets, address receiver) external returns (uint256); //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/1575cc6908f0f38bfb36d459c4ce7295f0f89c49/contracts/token/ERC20/extensions/ERC4626.sol#L132

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256); //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/740ce2d440766e5013640f0e47640fae57f5d1d5/contracts/token/ERC20/extensions/ERC4626.sol#L166

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}
