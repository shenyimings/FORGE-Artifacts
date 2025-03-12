// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "../../../src/interfaces/chainlink/AggregatorV3Interface.sol";

contract MockChainlinkPriceFeed is AggregatorV3Interface {
    address public immutable baseToken;
    address public immutable quoteToken;
    int256 public answer = 1e18;

    constructor(address _baseToken, address _quoteToken, int256 _exchangeRate) {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        answer = _exchangeRate;
    }

    function setLatestAnswer(int256 _answer) external {
        answer = _answer;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 _answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, answer, 0, 0, 0);
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    /*//////////////////////////////////////////////////////////////
                            UNUSED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function description() external view override returns (string memory) {}

    function version() external view override returns (uint256) {}

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 _answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {}
}
