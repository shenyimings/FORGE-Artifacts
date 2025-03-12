// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {DeployLeveragedEth} from "./base/DeployLeveragedEth.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {MockWETH} from "../test/mocks/MockWETH.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";
import {GoerliConstants as C} from "../src/lib/GoerliConstants.sol";

contract DeployScript is DeployLeveragedEth {
    function deployMockTokens() internal override {
        weth = MockWETH(payable(C.WETH));
        usdc = MockUSDC(C.USDC);
    }

    function run() external {
        deploy();
    }
}
