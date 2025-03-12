pragma solidity ^0.8.16;

// SPDX-License-Identifier: GPL-3.0-only

// https://github.com/rocket-pool/rocketpool/blob/master/contracts/interface/node/RocketNodeStakingInterface.sol

interface RocketNodeStakingInterface {
    function getTotalRPLStake() external view returns (uint256);

    function getNodeRPLStake(
        address _nodeAddress
    ) external view returns (uint256);

    function getNodeRPLStakedTime(
        address _nodeAddress
    ) external view returns (uint256);

    function getTotalEffectiveRPLStake() external view returns (uint256);

    function calculateTotalEffectiveRPLStake(
        uint256 offset,
        uint256 limit,
        uint256 rplPrice
    ) external view returns (uint256);

    function getNodeEffectiveRPLStake(
        address _nodeAddress
    ) external view returns (uint256);

    function getNodeMinimumRPLStake(
        address _nodeAddress
    ) external view returns (uint256);

    function getNodeMaximumRPLStake(
        address _nodeAddress
    ) external view returns (uint256);

    function getNodeMinipoolLimit(
        address _nodeAddress
    ) external view returns (uint256);

    function stakeRPL(uint256 _amount) external;

    function stakeRPLFor(address _nodeAddress, uint256 _amount) external;

    function withdrawRPL(uint256 _amount) external;

    function slashRPL(address _nodeAddress, uint256 _ethSlashAmount) external;
}
