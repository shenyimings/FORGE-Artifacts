// SPDX-License-Identifier: MIT
// solhint-disable state-visibility, max-states-count, var-name-mixedcase, no-global-import, const-name-snakecase, no-empty-blocks, no-console
pragma solidity 0.8.21;

import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";

contract MockAggregatorV3 is IAggregatorV3 {
    // Transmission records the answer from the transmit transaction at
    // time timestamp
    struct Transmission {
        int192 answer; // 192 bits ought to be enough for anyone
        uint64 timestamp;
    }

    mapping(uint32 => Transmission) internal s_transmissions; /* aggregator round ID */
    uint32 public latestAggregatorRoundId;
    /**
     * @return answers are stored in fixed-point format, with this many digits of precision
     */
    uint8 public immutable decimals = 8;

    /**
     * @notice aggregator contract version
     */
    uint256 public constant version = 1;

    string internal s_description;

    /**
     * @notice indicates that a new report was transmitted
     * @param aggregatorRoundId the round to which this report was assigned
     * @param answer value posted by validator
     * @param transmitter address from which the report was transmitted
     */
    event NewTransmission(uint32 indexed aggregatorRoundId, int192 answer, address transmitter);

    /**
     * @notice human-readable description of observable this contract is reporting on
     */
    function description() public view virtual returns (string memory) {
        return s_description;
    }

    /**
     * @notice details for the given aggregator round
     * @param _roundId target aggregator round. Must fit in uint32
     * @return roundId _roundId
     * @return answer answer of report from given _roundId
     * @return startedAt timestamp of block in which report from given _roundId was transmitted
     * @return updatedAt timestamp of block in which report from given _roundId was transmitted
     * @return answeredInRound _roundId
     */
    function getRoundData(
        uint80 _roundId
    )
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(_roundId <= 0xFFFFFFFF, "no data");
        Transmission memory transmission = s_transmissions[uint32(_roundId)];
        return (_roundId, transmission.answer, transmission.timestamp, transmission.timestamp, _roundId);
    }

    /**
     * @notice aggregator details for the most recently transmitted report
     * @return roundId aggregator round of latest report
     * @return answer answer of latest report
     * @return startedAt timestamp of block containing latest report
     * @return updatedAt timestamp of block containing latest report
     * @return answeredInRound aggregator round of latest report
     */
    function latestRoundData()
        public
        view
        virtual
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = latestAggregatorRoundId;

        // Skipped for compatability with existing FluxAggregator in which latestRoundData never reverts.
        // require(roundId != 0, V3_NO_DATA_ERROR);

        Transmission memory transmission = s_transmissions[uint32(roundId)];
        return (roundId, transmission.answer, transmission.timestamp, transmission.timestamp, roundId);
    }
}
