// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Strategies
import {BaseStrategyChainlinkPriceLatency} from "../../../../contracts/executionStrategies/Chainlink/BaseStrategyChainlinkPriceLatency.sol";

// Other tests
import {ProtocolBase} from "../../ProtocolBase.t.sol";

contract ChainlinkMaximumLatencyTest is ProtocolBase {
    event MaxLatencyUpdated(uint256 newMaxLatency);

    function _testSetMaximumLatency(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectEmit(true, false, false, true);
        emit MaxLatencyUpdated(3_600);
        vm.prank(_owner);
        strategy.updateMaxLatency(3_600);

        assertEq(strategy.maxLatency(), 3_600);
    }

    function _testSetMaximumLatencyLatencyToleranceTooHigh(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(BaseStrategyChainlinkPriceLatency.LatencyToleranceTooHigh.selector);
        vm.prank(_owner);
        strategy.updateMaxLatency(3_601);
    }

    function _testSetMaximumLatencyNotOwner(address _strategy) internal {
        BaseStrategyChainlinkPriceLatency strategy = BaseStrategyChainlinkPriceLatency(_strategy);

        vm.expectRevert(IOwnableTwoSteps.NotOwner.selector);
        strategy.updateMaxLatency(3_600);
    }
}
