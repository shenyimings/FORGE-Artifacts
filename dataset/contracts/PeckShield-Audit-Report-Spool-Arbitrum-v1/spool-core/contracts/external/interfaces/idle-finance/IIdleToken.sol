// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

interface IIdleToken {
    function decimals() external view returns (uint8);

    function getGovTokens() external view returns (address[] memory);

    function tokenPriceWithFee(address user) external view returns (uint256);

    function balanceOf(address user) external view returns (uint256);

    function redeemIdleToken(uint256 amount) external;

    function mintIdleToken(
        uint256 amount,
        bool,
        address referral
    ) external returns (uint256);
}
