// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.11;

interface IPoolMulti {
    function balances(address user) external view returns (uint256);

    function numRewardTokens() external view returns (uint256);
    
    function rewardTokens(uint256 i) external view returns (address);
    
    function poolToken() external view returns (address);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function claim_allTokens() external returns (uint256[] memory amounts);

    // claim calculates the currently owed reward and transfers the funds to the user
    function claim(address token) external returns (uint256);
}
