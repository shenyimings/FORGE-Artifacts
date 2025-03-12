// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.21;
import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";

contract MockOracle is IAggregatorV3 {
    uint8 public decimals = 8;
    string public override description;
    uint256 public override version = 1;
    int256 public initialAnswer;

    constructor(string memory _description, uint256 _initialAnswer, uint8 _decimals) {
        description = _description;
        initialAnswer = int256(_initialAnswer);
        decimals = _decimals;
    }

    function setPrice(uint256 _answer) external {
        initialAnswer = int256(_answer);
    }

    function price() external view returns (uint256) {
        return uint256(initialAnswer);
    }

    function getRoundData(
        uint80
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, initialAnswer, block.timestamp, block.timestamp, roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, initialAnswer, block.timestamp, block.timestamp, roundId);
    }
}
