// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IRewarder {
    function onBeetsReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 beetsAmount,
        uint256 newLpAmount
    ) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 beetsAmount
    ) external view returns (IERC20[] memory, uint256[] memory);
}
