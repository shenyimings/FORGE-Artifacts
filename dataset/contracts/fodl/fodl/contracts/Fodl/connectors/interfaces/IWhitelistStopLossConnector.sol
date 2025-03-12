// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IWhitelistStopLossConnector {
    function configureStopLoss(
        uint256 unwindFactor,
        uint256 slippageIncentive,
        uint256 collateralUsageLimit,
        address permittedBot
    ) external returns (bool);

    function executeStopLoss() external returns (uint256);

    function getStopLossConfiguration()
        external
        view
        returns (
            uint256 slippageIncentive,
            uint256 collateralUsageLimit,
            uint256 unwindFactor
        );

    function setStopLossWhitelistPermission(address addr, bool permission) external;

    function getStopLossWhitelistPermission(address addr) external returns (bool);

    function getStopLossState()
        external
        returns (
            bool canTriggerStopLoss,
            uint256 supplyBalance,
            uint256 borrowBalance,
            uint256 slippageIncentive,
            uint256 collateralUsageLimit,
            uint256 unwindFactor
        );
}
