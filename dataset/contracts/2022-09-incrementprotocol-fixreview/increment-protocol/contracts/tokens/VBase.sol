// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {VirtualToken} from "./VirtualToken.sol";
import {IncreAccessControl} from "../utils/IncreAccessControl.sol";

// interfaces
import {IVBase} from "../interfaces/IVBase.sol";
import {AggregatorV3Interface} from "../../lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// @notice ERC20 token traded on the CryptoSwap pool
contract VBase is IVBase, IncreAccessControl, VirtualToken {
    uint8 internal constant PRECISION = 18;
    uint256 public override heartBeat;

    AggregatorV3Interface public override aggregator;
    AggregatorV3Interface public override sequencerUptimeFeed;
    uint256 public override gracePeriod;

    constructor(
        string memory _name,
        string memory _symbol,
        AggregatorV3Interface _aggregator,
        uint256 _heartBeat,
        AggregatorV3Interface _sequencerUptimeFeed,
        uint256 _gracePeriod
    ) VirtualToken(_name, _symbol) {
        if (_aggregator.decimals() > PRECISION) revert VBase_InsufficientPrecision();
        aggregator = _aggregator;
        setHeartBeat(_heartBeat);
        setSequencerUptimeFeed(_sequencerUptimeFeed);
        setGracePeriod(_gracePeriod);
    }

    /* *************** */
    /*   Governance    */
    /* *************** */

    function setHeartBeat(uint256 newHeartBeat) public override onlyRole(GOVERNANCE) {
        if (newHeartBeat == 0) revert VBase_IncorrectHeartBeat();

        heartBeat = newHeartBeat;
        emit HeartBeatUpdated(newHeartBeat);
    }

    function setSequencerUptimeFeed(AggregatorV3Interface newSequencerUptimeFeed)
        public
        override
        onlyRole(GOVERNANCE)
    {
        if (address(newSequencerUptimeFeed) == address(0)) revert VBase_SequencerUptimeFeedZeroAddress();

        sequencerUptimeFeed = newSequencerUptimeFeed;
        emit SequencerUptimeFeedUpdated(newSequencerUptimeFeed);
    }

    function setGracePeriod(uint256 newGracePeriod) public override onlyRole(GOVERNANCE) {
        if (newGracePeriod < 60) revert VBase_IncorrectGracePeriod();
        if (newGracePeriod > 3600) revert VBase_IncorrectGracePeriod();

        gracePeriod = newGracePeriod;
        emit GracePeriodUpdated(newGracePeriod);
    }

    /* ****************** */
    /*   Global getter    */
    /* ****************** */

    function getIndexPrice() external view override returns (int256) {
        // Check if L2 sequencer up when transaction was received
        {
            (, int256 sequencerStatus, uint256 sequencerStatusLastUpdatedAt,,) = sequencerUptimeFeed.latestRoundData();

            // 0 means sequencer is up & 1 sequencer is down
            bool isSequencerUp = sequencerStatus == 0;
            if (!isSequencerUp) revert VBase_SequencerDown();

            // make sure the grace period has passed after the sequencer is back up
            uint256 timeSinceUp = block.timestamp - sequencerStatusLastUpdatedAt;

            if (timeSinceUp <= gracePeriod) revert VBase_GracePeriodNotOver();
        }

        return _chainlinkPrice(aggregator);
    }

    function _chainlinkPrice(AggregatorV3Interface chainlinkInterface) internal view returns (int256) {
        uint8 chainlinkDecimals = chainlinkInterface.decimals();
        (, int256 roundPrice,, uint256 roundTimestamp,) = chainlinkInterface.latestRoundData();

        // If the round is not complete yet, roundTimestamp is 0
        if (roundTimestamp <= 0) revert VBase_InvalidRoundTimestamp();
        if (roundPrice <= 0) revert VBase_InvalidRoundPrice();
        if (roundTimestamp + heartBeat < block.timestamp) revert VBase_DataNotFresh();

        int256 scaledPrice = (roundPrice * int256(10 ** (PRECISION - chainlinkDecimals)));
        return scaledPrice;
    }
}
