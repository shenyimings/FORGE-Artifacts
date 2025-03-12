// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

interface IDeFiAIMultiStrat {
    function deposit(address user, uint256 _wantAmt, address _wantAddress) external returns (uint256);
    function withdraw(address user, uint256 _wantAmt, address _wantAddress) external returns (uint256);
    function balances(address user) external view returns (uint256);
}
