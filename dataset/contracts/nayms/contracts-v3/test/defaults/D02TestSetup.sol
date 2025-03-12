// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { D01Deployment, console2, LibHelpers, LibConstants, LibAdmin, LibObject } from "./D01Deployment.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";

/// @notice Default test setup part 02
///         Setup test ERC20 tokens

contract D02TestSetup is D01Deployment {
    //// test tokens ////
    MockERC20 public weth;
    address public wethAddress;

    MockERC20 public wbtc;
    address public wbtcAddress;

    function setUp() public virtual override {
        super.setUp();
        weth = new MockERC20("Wrapped ETH", "WETH", 18);
        wbtc = new MockERC20("Wrapped BTC", "WBTC", 18);
        wethAddress = address(weth);
        wbtcAddress = address(wbtc);
        vm.label(wethAddress, "WETH");
        vm.label(wbtcAddress, "WBTC");
    }
}
