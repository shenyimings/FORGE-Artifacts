// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

contract MockRDNTOracle {
    uint256 private _latestAnswer;
    uint256 private _latestAnswerInEth;

    constructor(uint256 priceInUSD, uint256 priceInETH) {
        _latestAnswer = priceInUSD;
        _latestAnswerInEth = priceInETH;
    }

    function latestAnswer() external view returns (uint256) {
        return _latestAnswer;
    }

    function latestAnswerInEth() external view returns (uint256) {
        return _latestAnswerInEth;
    }

    function update() external pure {}

    function canUpdate() external pure returns (bool) {
        return true;
    }

    // function getSubTokens() external view returns (address[] memory) {
    // TODO: implement mock for when multiple subtokens. Maybe we need to create diff mock contract
    // to call it from the migration for this case??
    // }
}
