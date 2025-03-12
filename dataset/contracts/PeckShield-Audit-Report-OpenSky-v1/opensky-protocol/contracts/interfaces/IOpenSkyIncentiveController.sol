// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface IOpenSkyIncentiveController {
    function handleAction(
        address account,
        uint256 userBalance,
        uint256 totalSupply
    ) external;
}
