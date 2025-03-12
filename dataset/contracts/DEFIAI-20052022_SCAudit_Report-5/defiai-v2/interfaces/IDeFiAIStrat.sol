// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IDeFiAIStrat {
    function deposit(address user, uint256 _wantAmt) external returns (uint256);

    function withdraw(address user, uint256 _wantAmt) external returns (uint256);

    function getUserWant(address user) external view returns (uint256);
}
