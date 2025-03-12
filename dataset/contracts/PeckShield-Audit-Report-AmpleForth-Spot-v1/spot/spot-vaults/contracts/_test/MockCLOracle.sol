// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { IChainlinkOracle } from "../_interfaces/external/IChainlinkOracle.sol";

contract MockCLOracle is IChainlinkOracle {
    int256 private _answer;
    uint256 private _reportTime;

    function mockLastRoundData(int256 answer, uint256 reportTime) external {
        _answer = answer;
        _reportTime = reportTime;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (uint80(0), _answer, 0, _reportTime, uint80(0));
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
