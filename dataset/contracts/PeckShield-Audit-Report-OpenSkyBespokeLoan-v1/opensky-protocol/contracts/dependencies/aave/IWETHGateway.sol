// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IWETHGateway {
    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address onBehalfOf
    ) external;

    function getWETHAddress() external view returns (address);
}
