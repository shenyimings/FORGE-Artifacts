// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./IMarketConfig.sol";

contract MarketConfig is IMarketConfig {
    /// @notice Opening dispute price (FORE)
    /// @dev Used in order to disincentive spam
    uint256 public immutable override disputePrice;

    /// @notice Dispute period (in seconds)
    uint256 public immutable override disputePeriod;

    /// @notice Verification period (in seconds)
    uint256 public immutable override verificationPeriod;

    /// @notice Burn fee (1 = 0.01%)
    uint256 public immutable override burnFee;

    /// @notice Foundation fee (1 = 0.01%)
    uint256 public immutable override foundationFee;

    /// @notice Market creator fee (1 = 0.01%)
    uint256 public immutable override marketCreatorFee;

    /// @notice Verification fee (1 = 0.01%)
    uint256 public immutable override verificationFee;

    constructor(
        uint256 disputePriceP,
        uint256 disputePeriodP,
        uint256 verificationPeriodP,
        uint256 burnFeeP,
        uint256 foundationFeeP,
        uint256 marketCreatorFeeP,
        uint256 verificationFeeP
    ) {
        disputePrice = disputePriceP;
        disputePeriod = disputePeriodP;
        verificationPeriod = verificationPeriodP;
        burnFee = burnFeeP;
        foundationFee = foundationFeeP;
        marketCreatorFee = marketCreatorFeeP;
        verificationFee = verificationFeeP;
    }

    /**
     * @notice Returns all period values
     */
    function periods() external view override returns (uint256, uint256) {
        return (disputePeriod, verificationPeriod);
    }

    /**
     * @notice Returns all config values
     */
    function fees()
        external
        view
        override
        returns (uint256, uint256, uint256, uint256)
    {
        return (burnFee, foundationFee, marketCreatorFee, verificationFee);
    }

    /**
     * @notice Returns all fees values
     */
    function config()
        external
        view
        override
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        return (
            disputePrice,
            disputePeriod,
            verificationPeriod,
            burnFee,
            foundationFee,
            marketCreatorFee,
            verificationFee
        );
    }

    /**
     * @notice Returns sum of all fees (1 = 0.01%)
     */
    function feesSum() external view override returns (uint256) {
        return burnFee + foundationFee + marketCreatorFee + verificationFee;
    }
}
