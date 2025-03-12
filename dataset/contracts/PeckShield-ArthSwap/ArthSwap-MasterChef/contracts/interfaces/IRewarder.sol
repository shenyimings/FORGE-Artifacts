// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "boring-solidity/contracts/libraries/BoringERC20.sol";

interface IRewarder {
    using BoringERC20 for IERC20;

    function onARSWReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 arswAmount,
        uint256 newLpAmount
    ) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 arswAmount
    ) external view returns (IERC20[] memory, uint256[] memory);
}
