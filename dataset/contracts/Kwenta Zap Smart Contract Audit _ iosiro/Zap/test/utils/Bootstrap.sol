// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import {console2} from "../../lib/forge-std/src/console2.sol";
import {
    Zap,
    BaseGoerliParameters,
    BaseParameters,
    Setup
} from "../../script/Deploy.s.sol";
import {ZapEvents} from "./../../src/ZapEvents.sol";
import {Constants} from "./Constants.sol";
import {MockSpotMarketProxy} from "../utils/mocks/MockSpotMarketProxy.sol";
import {MockUSDC} from "../utils/mocks/MockUSDC.sol";
import {MockSUSD} from "../utils/mocks/MockSUSD.sol";
import {SynthetixV3Errors} from "./errors/SynthetixV3Errors.sol";
import {Test} from "../../lib/forge-std/src/Test.sol";
import {ZapExposed} from "../utils/exposed/ZapExposed.sol";

/// @title Bootstrap contract for setting up test environment
/// @author JaredBorders (jaredborders@pm.me)
contract Bootstrap is Test, ZapEvents, SynthetixV3Errors, Constants {
    using console2 for *;

    ZapExposed public zap;

    function initializeLocal() internal {
        BootstrapLocal bootstrap = new BootstrapLocal();
        (address zapAddress) = bootstrap.init();

        zap = ZapExposed(zapAddress);
    }

    function initializeBase() internal {
        BootstrapBase bootstrap = new BootstrapBase();
        (address zapAddress) = bootstrap.init();

        zap = ZapExposed(zapAddress);
    }

    function initializeBaseGoerli() internal {
        BootstrapBaseGoerli bootstrap = new BootstrapBaseGoerli();
        (address zapAddress) = bootstrap.init();

        zap = ZapExposed(zapAddress);
    }
}

contract BootstrapLocal is Setup, Constants {
    function init() public returns (address zapAddress) {
        zapAddress = Setup.deploySystem(
            address(new MockUSDC()),
            address(new MockSUSD()),
            address(new MockSpotMarketProxy()),
            type(uint128).max
        );
    }
}

contract BootstrapBase is Setup, BaseParameters {
    function init() public returns (address zapAddress) {
        zapAddress = Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );
    }
}

contract BootstrapBaseGoerli is Setup, BaseGoerliParameters {
    function init() public returns (address zapAddress) {
        zapAddress = Setup.deploySystem(
            USDC, USD_PROXY, SPOT_MARKET_PROXY, SUSDC_SPOT_MARKET_ID
        );
    }
}
