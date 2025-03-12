// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IPullRewardsTransferStrategy} from "@aave-v3-periphery/rewards/interfaces/IPullRewardsTransferStrategy.sol";

import {SafeTransferLib, ERC20} from "@solmate/utils/SafeTransferLib.sol";

contract PullRewardsTransferStrategyMock is IPullRewardsTransferStrategy {
    using SafeTransferLib for ERC20;

    function getIncentivesController() external view returns (address) {}

    function getRewardsAdmin() external view returns (address) {}

    function getRewardsVault() external view returns (address) {}

    function emergencyWithdrawal(address token, address to, uint256 amount) external {}

    function performTransfer(address to, address reward, uint256 amount) external returns (bool) {
        ERC20(reward).safeTransfer(to, amount);

        return true;
    }
}
