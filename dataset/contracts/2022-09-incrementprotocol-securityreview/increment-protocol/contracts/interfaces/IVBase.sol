// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {AggregatorV3Interface} from "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IVirtualToken} from "../interfaces/IVirtualToken.sol";

interface IVBase is IVirtualToken {
    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when oracle heart beat is updated
    /// @param newHeartBeat New heart beat value
    event HeartBeatUpdated(uint256 newHeartBeat);

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
    error VBase_IncorrectHeartBeat();

    /// @notice Emitted when the proposed aggregators decimals are less than PRECISION
    error VBase_InsufficientPrecision();

    /// @notice Emitted when the latest round is incomplete
    error VBase_InvalidRoundTimestamp();

    /// @notice Emitted when the latest round's price is invalid
    error VBase_InvalidRoundPrice();

    /// @notice Emitted when the latest round's data is older than the oracle's max refresh time
    error VBase_DataNotFresh();

    /// @notice Emitted when proposed sequencer uptime feed address is equal to the zero address
    error VBase_SequencerUptimeFeedZeroAddress();

    /// @notice Emitted when proposed grace period is outside of the bounds
    error VBase_IncorrectGracePeriod();

    /// @notice Emitted when Zksync sequencer is down
    error VBase_SequencerDown();

    /// @notice Emitted when Zksync sequencer hasn't been back up for long enough
    error VBase_GracePeriodNotOver();

    /* ****************** */
    /*     Viewer         */
    /* ****************** */

    function getIndexPrice() external view returns (int256);

    function heartBeat() external view returns (uint256);

    function sequencerUptimeFeed() external view returns (AggregatorV3Interface);

    function aggregator() external view returns (AggregatorV3Interface);

    function gracePeriod() external view returns (uint256);

    /* ****************** */
    /*  State modifying   */
    /* ****************** */

    function setHeartBeat(uint256 newHeartBeat) external;

    function setSequencerUptimeFeed(AggregatorV3Interface newSequencerUptimeFeed) external;

    function setGracePeriod(uint256 newGracePeriod) external;
}
