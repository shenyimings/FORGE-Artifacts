// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../src/external/interfaces/chainlink/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface {
    /* ========== STATE VARIABLES ========== */

    uint8 public decimals;
    string public description;
    uint256 public version;

    uint80 private latestRound;
    mapping(uint80 => int256) private roundAnswer;
    mapping(uint80 => uint256) private roundStartedAt;
    mapping(uint80 => uint256) private roundUpdatedAt;
    mapping(uint80 => uint80) private roundAnsweredInRound;

    /* ========== CONSTRUCTOR ========== */

    constructor(uint8 _decimals, string memory _description, uint256 _version) {
        decimals = _decimals;
        description = _description;
        version = _version;

        latestRound = 1;
    }

    function test_mock() external pure {}

    /* ========== ADMIN FUNCTIONS ========== */

    /**
     * @notice Creates a new round based on provided answer.
     */
    function pushAnswer(int256 answer) public {
        latestRound++;
        roundAnswer[latestRound] = answer;
        roundStartedAt[latestRound] = block.timestamp;
        roundUpdatedAt[latestRound] = block.timestamp;
        roundAnsweredInRound[latestRound] = latestRound;
    }

    /**
     * @notice Sets custom data for a round.
     */
    function setRoundData(uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
        public
    {
        roundAnswer[roundId] = answer;
        roundStartedAt[roundId] = startedAt;
        roundUpdatedAt[roundId] = updatedAt;
        roundAnsweredInRound[roundId] = answeredInRound;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            _roundId,
            roundAnswer[_roundId],
            roundStartedAt[_roundId],
            roundUpdatedAt[_roundId],
            roundAnsweredInRound[_roundId]
        );
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            latestRound,
            roundAnswer[latestRound],
            roundStartedAt[latestRound],
            roundUpdatedAt[latestRound],
            roundAnsweredInRound[latestRound]
        );
    }
}
