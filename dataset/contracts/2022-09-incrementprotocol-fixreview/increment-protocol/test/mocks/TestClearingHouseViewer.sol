// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {ClearingHouseViewer} from "../../contracts/ClearingHouseViewer.sol";

// interfaces
import {IClearingHouse} from "../../contracts/interfaces/IClearingHouse.sol";

// libraries
import {LibPerpetual} from "../../contracts/lib/LibPerpetual.sol";
import {LibMath} from "../../contracts/lib/LibMath.sol";

contract TestClearingHouseViewer is ClearingHouseViewer {
    using LibMath for uint256;
    using LibMath for int256;

    constructor(IClearingHouse _clearingHouse) ClearingHouseViewer(_clearingHouse) {}

    // simplified getter with fixed time
    function __TestClearingHouseViewer__getUpdatedTwapAtTimestamp(uint256 idx, uint256 currentTime)
        public
        view
        returns (int256 oracleTwap, int256 marketTwap)
    {
        LibPerpetual.GlobalPosition memory globalPosition = getGlobalPosition(idx);

        uint256 timeElapsedSinceBeginningOfPeriod = block.timestamp - globalPosition.timeOfLastTwapUpdate;

        if (timeElapsedSinceBeginningOfPeriod >= perpetual(idx).twapFrequency()) {
            // update intermediary input
            // @dev: reference the perpetual contract for more details
            int256 timeElapsed = (currentTime - globalPosition.timeOfLastTrade).toInt256();

            int256 latestChainlinkPrice = indexPrice(idx);
            int256 oracleCumulativeAmount = perpetual(idx).oracleCumulativeAmount() + latestChainlinkPrice * timeElapsed;

            int256 latestMarketPrice = marketPrice(idx).toInt256();
            int256 marketCumulativeAmount = perpetual(idx).marketCumulativeAmount() + latestMarketPrice * timeElapsed;

            // update twap
            oracleTwap = (oracleCumulativeAmount - perpetual(idx).oracleCumulativeAmountAtBeginningOfPeriod())
                / timeElapsedSinceBeginningOfPeriod.toInt256();

            marketTwap = (marketCumulativeAmount - perpetual(idx).marketCumulativeAmountAtBeginningOfPeriod())
                / timeElapsedSinceBeginningOfPeriod.toInt256();
        } else {
            oracleTwap = perpetual(idx).oracleTwap();
            marketTwap = perpetual(idx).marketTwap();
        }
    }

    function __TestClearingHouseViewer__getUpdatedFundingRateAtTimestamp(uint256 idx, uint256 currentTime)
        public
        view
        returns (int256 cumFundingRate, int256 cumFundingPerLpToken)
    {
        LibPerpetual.GlobalPosition memory globalPosition = getGlobalPosition(idx);

        if (currentTime > globalPosition.timeOfLastTrade) {
            (int256 oracleTwap, int256 marketTwap) =
                __TestClearingHouseViewer__getUpdatedTwapAtTimestamp(idx, currentTime);

            int256 currentTraderPremium = marketTwap - oracleTwap;
            int256 timePassedSinceLastTrade = (currentTime - globalPosition.timeOfLastTrade).toInt256();

            int256 fundingRate =
                ((perpetual(idx).sensitivity().wadMul(currentTraderPremium) * timePassedSinceLastTrade) / 1 days); // @dev: in fixed number x seconds / seconds = fixed number

            cumFundingRate = globalPosition.cumFundingRate + fundingRate;

            int256 tokenSupply =
                getTotalLiquidityProvided(idx).toInt256() > 0 ? getTotalLiquidityProvided(idx).toInt256() : int256(1e18);

            int256 totalTraderPositionSize =
                uint256(globalPosition.traderLongs).toInt256() - uint256(globalPosition.traderShorts).toInt256();

            cumFundingPerLpToken += totalTraderPositionSize > 0
                ? -fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply) // long pay funding
                : fundingRate.wadMul(totalTraderPositionSize).wadDiv(tokenSupply); // short receives funding
        } else {
            cumFundingRate = globalPosition.cumFundingRate;
            cumFundingPerLpToken = globalPosition.cumFundingPerLpToken;
        }
    }

    /// @notice Calculate missed funding payments
    /// @param idx Index of the perpetual market
    /// @param account User to get the funding payments of
    /// @param currentTime Hardcoded timestamp to calculate the funding payments
    function __TestClearingHouseViewer__getTraderFundingPaymentsAtTimestamp(
        uint256 idx,
        address account,
        uint256 currentTime
    ) public view returns (int256 pendingFunding) {
        LibPerpetual.TraderPosition memory trader = getTraderPosition(idx, account);

        (int256 cumFundingRate,) = __TestClearingHouseViewer__getUpdatedFundingRateAtTimestamp(idx, currentTime);

        return _getTraderFundingPayments(
            trader.positionSize >= 0, trader.cumFundingRate, cumFundingRate, int256(trader.positionSize).abs()
        );
    }

    /// @notice Calculate missed funding payments
    /// @param idx Index of the perpetual market
    /// @param account User to get the funding payments of
    /// @param currentTime Hardcoded timestamp to calculate the funding payments
    function __TestClearingHouseViewer__getLpFundingPaymentsAtTimestamp(
        uint256 idx,
        address account,
        uint256 currentTime
    ) public view returns (int256 pendingFunding) {
        LibPerpetual.LiquidityProviderPosition memory lp = getLpPosition(idx, account);

        (, int256 cumFundingPerLpToken) = __TestClearingHouseViewer__getUpdatedFundingRateAtTimestamp(idx, currentTime);

        return _getLpFundingPayments(lp.cumFundingPerLpToken, cumFundingPerLpToken, lp.liquidityBalance);
    }

    function __TestClearingHouseViewer__getTraderProposedAmount(
        uint256 idx,
        address user,
        uint256 reductionRatio,
        uint256 iter,
        uint256 minAmount,
        uint256 precision
    ) external view returns (uint256 proposedAmount) {
        // slither-disable-next-line missing-zero-check,low-level-calls
        (bool status, bytes memory value) = address(this).staticcall(
            abi.encodeCall(
                this.getTraderProposedAmountStruct,
                TraderProposedAmountArgs(idx, user, reductionRatio, iter, minAmount, precision)
            )
        );

        // bubble up error message
        if (!status) {
            // slither-disable-next-line assembly
            assembly {
                revert(add(value, 0x20), mload(value))
            }
        }

        return uint256(bytes32(value));
    }

    function __TestClearingHouseViewer__getLpProposedAmount(
        uint256 idx,
        address user,
        uint256 reductionRatio,
        uint256 iter,
        uint256[2] calldata minVTokenAmounts,
        uint256 minAmount,
        uint256 precision
    ) external returns (uint256 proposedAmount) {
        return this.getLpProposedAmountStruct(
            LpProposedAmountArgs(idx, user, reductionRatio, iter, minVTokenAmounts, minAmount, precision)
        );
    }
}
