// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

interface IBuyBack {
    function buyAndBurnToken(
        address,
        uint256,
        address
    ) external returns (uint256);
}
