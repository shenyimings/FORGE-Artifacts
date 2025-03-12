// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "./../../interfaces/IStrategyStatistics.sol";
import "./../../interfaces/IMultiLogicProxy.sol";

struct RebalanceParam {
    address strategyStatistics;
    address logic;
    address supplyXToken;
    address strategyXToken;
    uint256 borrowRateMin;
    uint256 borrowRateMax;
    uint256 circlesCount;
    uint256 supplyBorrowLimitUSD;
    uint256 collateralFactorStrategy;
    uint256 collateralFactorStrategyApplied;
}

struct RewardsTokenPriceInfo {
    uint256 latestAnswer;
    uint256 timestamp;
}

struct SwapInfo {
    address[] swapRouters;
    address[][] paths;
}

library LendBorrowLendStrategyHelper {
    using SafeCastUpgradeable for uint256;

    uint256 internal constant BASE = 10**DECIMALS;
    uint256 internal constant DECIMALS = 18;

    /**
     * @notice Get BorrowRate of strategy
     * @param strategyStatistics Address of Statistics
     * @param logic Address of strategy's logic
     * @param supplyXToken XToken address for supplying
     * @param strategyXToken XToken address for circle
     * @return isLending true : there is supply, false : there is no supply
     * @return borrowRate borrowAmountUSD / borrowLimitUSD (decimals = 18)
     */
    function getBorrowRate(
        address strategyStatistics,
        address logic,
        address supplyXToken,
        address strategyXToken
    ) public view returns (bool isLending, uint256 borrowRate) {
        uint256 totalSupply;
        uint256 borrowLimit;
        uint256 borrowAmount;

        if (supplyXToken == strategyXToken) {
            (totalSupply, borrowLimit, borrowAmount) = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfoCompact(strategyXToken, logic);
        } else {
            XTokenInfo memory supplyInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(supplyXToken, logic);
            XTokenInfo memory strategyInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(strategyXToken, logic);

            totalSupply =
                supplyInfo.totalSupplyUSD +
                strategyInfo.totalSupplyUSD;
            borrowLimit =
                supplyInfo.borrowLimitUSD +
                strategyInfo.borrowLimitUSD;
            borrowAmount = strategyInfo.borrowAmountUSD;
        }

        // If no lending, can't rebalance
        isLending = totalSupply > 0 ? true : false;
        borrowRate = borrowLimit == 0 ? 0 : (borrowAmount * BASE) / borrowLimit;
    }

    /**
     * @notice Get BorrowRate of strategy
     * @return amount amount > 0 : build Amount, amount < 0 : destroy Amount
     */
    function getRebalanceAmount(RebalanceParam memory param)
        public
        view
        returns (int256 amount, uint256 priceUSD)
    {
        uint256 borrowRate;
        uint256 targetBorrowRate = param.borrowRateMin +
            (param.borrowRateMax - param.borrowRateMin) /
            2;
        uint256 totalSupply;
        uint256 borrowLimit;
        uint256 borrowAmount;
        uint256 P = 0; // Borrow Limit of supplyXToken

        if (param.supplyXToken == param.strategyXToken) {
            (totalSupply, borrowLimit, borrowAmount) = IStrategyStatistics(
                param.strategyStatistics
            ).getStrategyXTokenInfoCompact(param.strategyXToken, param.logic);

            borrowRate = borrowLimit == 0
                ? 0
                : (borrowAmount * BASE) / borrowLimit;
        } else {
            XTokenInfo memory strategyInfo = IStrategyStatistics(
                param.strategyStatistics
            ).getStrategyXTokenInfo(param.strategyXToken, param.logic);

            borrowRate = (param.supplyBorrowLimitUSD +
                strategyInfo.borrowLimitUSD) == 0
                ? 0
                : (strategyInfo.borrowAmountUSD * BASE) /
                    (param.supplyBorrowLimitUSD + strategyInfo.borrowLimitUSD);

            totalSupply = strategyInfo.totalSupplyUSD;
            borrowAmount = strategyInfo.borrowAmountUSD;
            P = param.supplyBorrowLimitUSD;
            priceUSD = strategyInfo.priceUSD;
        }

        // Build
        if (borrowRate < param.borrowRateMin) {
            uint256 Y = 0;
            {
                uint256 accLTV = BASE;
                for (uint256 i = 0; i < param.circlesCount; ) {
                    Y = Y + accLTV;
                    accLTV =
                        (accLTV * param.collateralFactorStrategyApplied) /
                        BASE;
                    unchecked {
                        ++i;
                    }
                }
            }
            uint256 buildAmount = ((((((totalSupply * targetBorrowRate) /
                BASE) * param.collateralFactorStrategy) / BASE) +
                (targetBorrowRate * P) /
                BASE -
                borrowAmount) * BASE) /
                ((Y *
                    (BASE -
                        (targetBorrowRate * param.collateralFactorStrategy) /
                        BASE)) / BASE);
            amount = (buildAmount).toInt256();
        }

        // Destroy
        if (borrowRate > param.borrowRateMax) {
            uint256 destroyAmount = ((borrowAmount -
                (P * targetBorrowRate) /
                BASE -
                (((totalSupply * targetBorrowRate) / BASE) *
                    param.collateralFactorStrategy) /
                BASE) * BASE) /
                (BASE -
                    (targetBorrowRate * param.collateralFactorStrategy) /
                    BASE);

            amount = 0 - (destroyAmount).toInt256();
        }

        // Calculate token amount base on USD price
        if (param.supplyXToken != param.strategyXToken) {
            amount = (amount * (BASE).toInt256()) / (priceUSD).toInt256();
        }
    }

    function getDestroyAmountForRelease(
        address strategyStatistics,
        address logic,
        uint256 releaseAmount,
        address supplyXToken,
        address strategyXToken,
        uint256 supplyBorrowLimitUSD,
        uint256 supplyPriceUSD,
        uint256 collateralFactorSupply,
        uint256 collateralFactorStrategy
    ) public view returns (uint256 destroyAmount, uint256 strategyPriceUSD) {
        if (supplyXToken == strategyXToken) {
            (uint256 totalSupply, , uint256 borrowAmount) = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfoCompact(strategyXToken, logic);

            destroyAmount =
                (borrowAmount * releaseAmount) /
                (totalSupply - borrowAmount);
        } else {
            XTokenInfo memory strategyInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(strategyXToken, logic);

            strategyPriceUSD = strategyInfo.priceUSD;

            // Convert releaseAmount to USD
            releaseAmount = (releaseAmount * supplyPriceUSD) / BASE;

            // Calculate destroyAmount in USD
            destroyAmount = (((releaseAmount * collateralFactorSupply) / BASE) *
                strategyInfo.borrowAmountUSD);
            destroyAmount =
                destroyAmount /
                (supplyBorrowLimitUSD +
                    (strategyInfo.totalSupplyUSD * collateralFactorStrategy) /
                    BASE -
                    (strategyInfo.borrowAmountUSD * collateralFactorStrategy) /
                    BASE);

            // Convert destroyAmount to Token
            destroyAmount = (destroyAmount * BASE) / strategyPriceUSD;
        }
    }

    function getDiffAmountForClaim(
        address strategyStatistics,
        address logic,
        address multiLogicProxy,
        address supplyXToken,
        address strategyXToken,
        address supplyToken,
        address strategyToken
    ) public view returns (int256 diffSupply, int256 diffStrategy) {
        if (supplyXToken == strategyXToken) {
            (uint256 totalSupply, , uint256 borrowAmount) = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfoCompact(strategyXToken, logic);

            diffSupply =
                (
                    IMultiLogicProxy(multiLogicProxy).getTokenTaken(
                        strategyToken,
                        logic
                    )
                ).toInt256() -
                (totalSupply).toInt256() +
                (borrowAmount).toInt256();
            diffStrategy = diffSupply;
        } else {
            XTokenInfo memory supplyInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(supplyXToken, logic);

            XTokenInfo memory strategyInfo = IStrategyStatistics(
                strategyStatistics
            ).getStrategyXTokenInfo(strategyXToken, logic);

            uint256 lendingAmountUSD = (IMultiLogicProxy(multiLogicProxy)
                .getTokenTaken(supplyToken, logic) * supplyInfo.priceUSD) /
                BASE;

            int256 diff = (lendingAmountUSD).toInt256() -
                (supplyInfo.totalSupplyUSD).toInt256() -
                (strategyInfo.totalSupplyUSD).toInt256() +
                (strategyInfo.borrowAmountUSD).toInt256();
            diffSupply =
                (diff * (BASE).toInt256()) /
                (supplyInfo.priceUSD).toInt256();
            diffStrategy =
                (diff * (BASE).toInt256()) /
                (strategyInfo.priceUSD).toInt256();
        }
    }

    function checkSwapInfo(
        SwapInfo memory swapInfo,
        uint8 swapPurpose,
        address supplyToken,
        address strategyToken,
        address rewardsToken,
        address blid
    ) public pure {
        require(swapInfo.swapRouters.length == swapInfo.paths.length, "C6");
        require(swapPurpose < 5, "C3");
        if (swapPurpose == 0 || swapPurpose == 1) {
            require(swapInfo.paths[0][0] == rewardsToken, "C7");
        } else if (swapPurpose == 2 || swapPurpose == 3) {
            require(swapInfo.paths[0][0] == strategyToken, "C7");
        } else {
            require(swapInfo.paths[0][0] == supplyToken, "C7");
        }
        if (swapPurpose == 1) {
            require(
                swapInfo.paths[swapInfo.paths.length - 1][
                    swapInfo.paths[swapInfo.paths.length - 1].length - 1
                ] == strategyToken,
                "C8"
            );
        } else if (swapPurpose == 3) {
            require(
                swapInfo.paths[swapInfo.paths.length - 1][
                    swapInfo.paths[swapInfo.paths.length - 1].length - 1
                ] == supplyToken,
                "C8"
            );
        } else {
            require(
                swapInfo.paths[swapInfo.paths.length - 1][
                    swapInfo.paths[swapInfo.paths.length - 1].length - 1
                ] == blid,
                "C8"
            );
        }
    }

    function checkRewardsPriceKillSwitch(
        address strategyStatistics,
        address comptroller,
        address rewardsToken,
        uint256 amountRewardsToken,
        RewardsTokenPriceInfo memory rewardsTokenPriceInfo,
        uint256 rewardsTokenPriceDeviationLimit,
        uint256 minRewardsSwapLimit
    ) public view returns (uint256 latestAnswer, bool killSwitch) {
        killSwitch = false;

        // Get latest Answer
        latestAnswer = IStrategyStatistics(strategyStatistics)
            .getRewardsTokenPrice(comptroller, rewardsToken);

        // Calculate Delta
        int256 delta = (rewardsTokenPriceInfo.latestAnswer).toInt256() -
            (latestAnswer).toInt256();
        if (delta < 0) delta = 0 - delta;

        // Check deviation
        if (
            block.timestamp == rewardsTokenPriceInfo.timestamp ||
            rewardsTokenPriceInfo.latestAnswer == 0
        ) {
            delta = 0;
        } else {
            delta =
                (delta * (1 ether)) /
                ((rewardsTokenPriceInfo.latestAnswer).toInt256() *
                    ((block.timestamp).toInt256() -
                        (rewardsTokenPriceInfo.timestamp).toInt256()));
        }
        if (uint256(delta) > rewardsTokenPriceDeviationLimit) {
            killSwitch = true;
        }

        // If rewards balance is below limit, activate kill switch
        if (amountRewardsToken <= minRewardsSwapLimit) killSwitch = true;
    }
}
