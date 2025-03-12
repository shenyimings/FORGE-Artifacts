// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {AggregatorV3Interface} from "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @notice Oracle interface created to ease oracle contract switch
interface IOracle {
    struct AssetOracle {
        uint24 heartBeat;
        AggregatorV3Interface aggregator; // aggregator of the ERC20 token for ERC4626 tokens
        bool isVaultAsset;
        int256 fixedPrice;
    }

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when oracle heart beat is added or updated
    /// @param asset Asset that got linked to an oracle
    /// @param aggregator Chainlink aggregator used as the asset oracle
    /// @param isVault True if the asset is a ERC-4626 vault asset
    event OracleUpdated(address asset, AggregatorV3Interface aggregator, bool isVault);

    /// @notice Emitted when an asset got a fixed price when requesting an oracle
    /// @param asset Asset which got a fixed price
    /// @param fixedPrice Fixed price that the asset got
    event AssetGotFixedPrice(address asset, int256 fixedPrice);

    /// @notice Emitted when oracle heart beat is updated
    /// @param asset Asset whose heartBeat is updated
    /// @param newHeartBeat New heart beat value
    event HeartBeatUpdated(address asset, uint24 newHeartBeat);

    /// @notice Emitted when sequencer uptime feed is updated
    /// @param newSequencerUptimeFeed New sequencer uptime feed
    event SequencerUptimeFeedUpdated(AggregatorV3Interface newSequencerUptimeFeed);

    /// @notice Emitted when grace period is updated
    /// @param newGracePeriod New grace period
    event GracePeriodUpdated(uint256 newGracePeriod);

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when the proposed heart beat is less than 1 sec second
    error Oracle_IncorrectHeartBeat();

    /// @notice Emitted when the latest round is incomplete
    error Oracle_InvalidRoundTimestamp();

    /// @notice Emitted when the latest round's price is invalid
    error Oracle_InvalidRoundPrice();

    /// @notice Emitted when the latest round's data is older than the oracle's max refresh time
    error Oracle_DataNotFresh();

    /// @notice Emitted when the proposed asset address is equal to the zero address
    error Oracle_AssetZeroAddress();

    /// @notice Emitted when the proposed aggregator address is equal to the zero address
    error Oracle_AggregatorZeroAddress();

    /// @notice Emitted when the proposed sequencer uptime feed address is equal to the zero address
    error Oracle_SequencerUptimeFeedZeroAddress();

    /// @notice Emitted when owner tries to set fixed price to an unsupported asset
    error Oracle_UnsupportedAsset();

    /// @notice Emitted when Zksync sequencer is down
    error Oracle_SequencerDown();

    /// @notice Emitted when Zksync sequencer hasn't been back up for long enough
    error Oracle_GracePeriodNotOver();

    /// @notice Emitted when proposed grace period doesn't fit in the defined bounds
    error Oracle_IncorrectGracePeriod();

    /* ****************** */
    /*     Viewer         */
    /* ****************** */

    function gracePeriod() external view returns (uint256);

    function sequencerUptimeFeed() external view returns (AggregatorV3Interface);

    function getPrice(address asset, int256 balance) external view returns (int256);

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function setOracle(address asset, AggregatorV3Interface aggregator, uint24 heartBeat, bool isVault) external;

    function setFixedPrice(address asset, int256 fixedPrice) external;

    function setHeartBeat(address asset, uint24 newHeartBeat) external;

    function setSequencerUptimeFeed(AggregatorV3Interface newSequencerUptimeFeed) external;

    function setGracePeriod(uint256 newGracePeriod) external;
}
