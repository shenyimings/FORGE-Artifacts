// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../LiquidityMining.sol";

contract MockLiquidityMining is LiquidityMining {
    uint private _blockTimestamp;

    function setBlockTimestamp(uint timestamp) external {
        _blockTimestamp = timestamp;
    }

    function getBlockTimestamp() public override view returns (uint) {
        return _blockTimestamp;
    }

    function harnessTransferReward(address rewardToken, address user, uint amount) external returns (uint) {
        return transferReward(rewardToken, user, amount);
    }

    function harnessUpdateGlobalSupplyIndex(address rewardToken, address cToken) external {
        updateGlobalSupplyIndex(rewardToken, cToken);
    }

    function harnessUpdateGlobalBorrowIndex(address rewardToken, address cToken) external {
        updateGlobalBorrowIndex(rewardToken, cToken);
    }
}
