// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

interface BathToken {


    function deposit(uint256 assets) external returns (uint256 shares);

    function withdraw(uint256 shares) external returns (uint256 assets);

    function maxWithdraw(address owner) external view returns (uint256 shares);

    function balanceOf(address owner) external view returns (uint256 shares);

    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function feeBPS() external view returns (uint256 fee);

}

