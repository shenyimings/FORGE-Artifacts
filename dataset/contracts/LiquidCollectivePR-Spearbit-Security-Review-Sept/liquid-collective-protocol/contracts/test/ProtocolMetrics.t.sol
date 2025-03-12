//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {RiverMock} from "./RedeemManager.1.t.sol";
import "./utils/LibImplementationUnbricker.sol";

import {ProtocolMetricsV1} from "./../src/ProtocolMetrics.1.sol";

contract ProtocolMetricsTest is Test {
    RiverMock river;
    ProtocolMetricsV1 protocolMetrics;

    function setUp() external {
        river = new RiverMock(address(0x00));
        protocolMetrics = new ProtocolMetricsV1();
        LibImplementationUnbricker.unbrick(vm, address(protocolMetrics));

        protocolMetrics.initProtocolMetricsV1(address(river));
    }

    function testGetRate(uint256 _rate) external {
        vm.assume(_rate > 0 && _rate < type(uint128).max);
        river.sudoSetRate(_rate);

        assertEq(protocolMetrics.getRate(), river.underlyingBalanceFromShares(1e18));
    }
}
