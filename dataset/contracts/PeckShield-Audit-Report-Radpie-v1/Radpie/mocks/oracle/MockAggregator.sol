// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

contract MockAggregator {
    uint256 private _latestAnswer;

    uint256 public constant HEART_RATE_TOLERANCE = 300;

    address public chainlinkFeed = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    uint256 public constant GRACE_PERIOD_TIME = 3600;
    uint256 public constant UPDATE_PERIOD = 86400;

    uint256 public constant heartbeat = 86400;

    event AnswerUpdated(uint256 indexed current, uint256 indexed roundId, uint256 timestamp);

    constructor(uint256 _initialAnswer) {
        _latestAnswer = _initialAnswer;
        emit AnswerUpdated(_initialAnswer, 0, block.timestamp);
    }

    function latestAnswer() external view returns (uint256) {
        return _latestAnswer;
    }

    function validate(uint256 _answer, uint256 updateAt) external pure {
        return;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    // function getSubTokens() external view returns (address[] memory) {
    // TODO: implement mock for when multiple subtokens. Maybe we need to create diff mock contract
    // to call it from the migration for this case??
    // }
}
