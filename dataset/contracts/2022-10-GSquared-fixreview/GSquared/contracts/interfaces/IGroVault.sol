// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

interface IGroVault {
    function getStrategiesLength() external view returns (uint256);

    function strategyHarvestTrigger(uint256 index, uint256 callCost)
        external
        view
        returns (bool);

    function getStrategyAssets(uint256 index) external view returns (uint256);
}
