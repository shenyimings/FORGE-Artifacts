// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

import { IYieldOracle } from "../../src/interfaces/IYieldOracle.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract FakeYieldOracle is IYieldOracle {
    IERC20 public override generatorToken;
    IERC20 public override yieldToken;
    uint256 public yieldPerSecond;
    uint256 public immutable decimals;

    constructor(address generatorToken_,
                address yieldToken_,
                uint256 yieldPerSecond_,
                uint256 decimals_) {
        generatorToken = IERC20(generatorToken_);
        yieldToken = IERC20(yieldToken_);
        yieldPerSecond = yieldPerSecond_;
        decimals = decimals_;
    }

    function projectYield(uint256 amount, uint256 duration) external override view returns (uint256) {
        return (amount * yieldPerSecond * duration) / (1e18);
    }
}
