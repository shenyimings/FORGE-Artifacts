// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IInterestRate.sol";

contract TieredInterestRate is IInterestRate {
    uint constant SCALE = 1e36;

    // 30 secs per block
    uint256 public constant BLOCKS_PER_DAY = (24 * 3600) / 30;
    uint256 public constant BLOCKS_PER_YEAR = BLOCKS_PER_DAY * 365;

    // blocks of 120 days
    uint256 public constant BLOCKS_120_DAYS = 120 * BLOCKS_PER_DAY;
    // blocks of 240 days
    uint256 public constant BLOCKS_240_DAYS = 240 * BLOCKS_PER_DAY;
    // blocks of 360 days
    uint256 public constant BLOCKS_360_DAYS = 360 * BLOCKS_PER_DAY;

    // interest rate per block when holding duration < 120 days -- 6%
    uint256 public constant BLOCK_RATE_HOLDING_LE_120 = (6 * SCALE) / 100 / BLOCKS_PER_YEAR;
    // interest rate per block when holding duration < 240 days -- 8%
    uint256 public constant BLOCK_RATE_HOLDING_LE_240 = (8 * SCALE) / 100 / BLOCKS_PER_YEAR;
    // interest rate per block when holding duration < 360 days -- 10%
    uint256 public constant BLOCK_RATE_HOLDING_LE_360 = (10 * SCALE) / 100 / BLOCKS_PER_YEAR;
    // interest rate per block when holding duration >= 360 days -- 12%
    uint256 public constant BLOCK_RATE_HOLDING_GT_360 = (12 * SCALE) / 100 / BLOCKS_PER_YEAR;

    // interest rate in subscription stage
    uint256 public constant BLOCK_RATE_SUBSCRIPTION = BLOCK_RATE_HOLDING_LE_120;

    function calculate(
        uint256 principal,
        uint256 beginSubscriptionBlock,
        uint256 endSubscriptionBlock,
        uint256 beginBlock,
        uint256 endBlock
    ) external view override returns (uint256) {
        require(
            beginSubscriptionBlock < endSubscriptionBlock &&
                beginBlock < endBlock,
            "illegal block range 1"
        );

        // before subscription
        if (block.number < beginSubscriptionBlock) {
            return 0;
        }

        // in subscription
        if (block.number < endSubscriptionBlock) {
            require(
                beginBlock >= beginSubscriptionBlock &&
                    endBlock <= endSubscriptionBlock,
                "illegal block range 2"
            );
            return (principal * BLOCK_RATE_SUBSCRIPTION * (endBlock - beginBlock)) / SCALE;
        }

        // online
        require(
            beginBlock >= endSubscriptionBlock && endBlock <= block.number,
            "illegal block range 3"
        );

        uint256 blockDelta = endBlock - beginBlock;
        uint256 holdingDuration = block.number - endSubscriptionBlock;
        if (holdingDuration <= BLOCKS_120_DAYS) {
            return (principal * BLOCK_RATE_HOLDING_LE_120 * blockDelta) / SCALE;
        } else if (holdingDuration <= BLOCKS_240_DAYS) {
            return (principal * BLOCK_RATE_HOLDING_LE_240 * blockDelta) / SCALE;
        } else if (holdingDuration <= BLOCKS_360_DAYS) {
            return (principal * BLOCK_RATE_HOLDING_LE_360 * blockDelta) / SCALE;
        } else {
            return (principal * BLOCK_RATE_HOLDING_GT_360 * blockDelta) / SCALE;
        }
    }

    function nowAPR(
        uint256 beginSubscriptionBlock,
        uint256 endSubscriptionBlock
    ) external view override returns (string memory) {
        beginSubscriptionBlock;

        if (block.number < endSubscriptionBlock) {
            return "0%";
        } else {
            uint256 holdingDuration = block.number - endSubscriptionBlock;
            if (holdingDuration <= BLOCKS_120_DAYS) {
                return "6%";
            } else if (holdingDuration <= BLOCKS_240_DAYS) {
                return "8%";
            } else if (holdingDuration <= BLOCKS_360_DAYS) {
                return "10%";
            } else {
                return "12%";
            }
        }
    }
}
