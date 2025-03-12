// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import "./mocks/MockRiskManager.sol";
import "../src/interfaces/IAllocationProvider.sol";
import "../src/providers/UniformAllocationProvider.sol";
import "../src/providers/LinearAllocationProvider.sol";
import "../src/providers/ExponentialAllocationProvider.sol";

contract FixedRM is MockRiskManager {
    function test_mock_() external pure {}

    function getRiskScores(address riskProvider, address[] calldata strategies)
        external
        pure
        override
        returns (uint8[] memory)
    {
        uint8[] memory results = new uint8[](strategies.length);

        if (riskProvider == address(100)) {
            for (uint8 i = 0; i < strategies.length; i++) {
                address str = strategies[i];
                if (str == address(101)) {
                    results[0] = 3_4;
                }
                if (str == address(102)) {
                    results[1] = 11_0;
                }
                if (str == address(103)) {
                    results[2] = 4_0;
                }
            }
        } else {
            revert("FixedRM::getRiskScore");
        }
        return results;
    }
}

contract AllocationProviderTest is Test {
    address strategy1 = address(101);
    address strategy2 = address(102);
    address strategy3 = address(103);

    int256 apy_strategy1 = 124; // 1.24%
    int256 apy_strategy2 = 220; // 2.20%
    int256 apy_strategy3 = 400; // 4.0%

    address riskProvider = address(100);

    int8 riskTolerance = 5;

    function test_uniformAllocationProvider() public {
        address[] memory strategies = new address[](3);
        strategies[0] = strategy1;
        strategies[1] = strategy2;
        strategies[2] = strategy3;

        int256[] memory apys = new int256[](3);
        apys[0] = apy_strategy1;
        apys[1] = apy_strategy2;
        apys[2] = apy_strategy3;

        FixedRM rm = new FixedRM();
        AllocationCalculationInput memory input =
            AllocationCalculationInput(strategies, apys, rm.getRiskScores(riskProvider, strategies), riskTolerance);

        IAllocationProvider ap = new UniformAllocationProvider();

        uint256[] memory results = ap.calculateAllocation(input);
        uint256 sum;
        for (uint8 i = 0; i < results.length; i++) {
            sum += results[i];
        }

        assertEq(sum, 100_00);
        assertEq(3334, results[0]);
        assertEq(3333, results[1]);
        assertEq(3333, results[2]);
    }

    function test_linearAllocationProvider() public {
        address[] memory strategies = new address[](3);
        strategies[0] = strategy1;
        strategies[1] = strategy2;
        strategies[2] = strategy3;

        int256[] memory apys = new int256[](3);
        apys[0] = apy_strategy1;
        apys[1] = apy_strategy2;
        apys[2] = apy_strategy3;

        FixedRM rm = new FixedRM();
        AllocationCalculationInput memory input =
            AllocationCalculationInput(strategies, apys, rm.getRiskScores(riskProvider, strategies), riskTolerance);

        IAllocationProvider ap = new AllocationProviderLinear();

        uint256[] memory results = ap.calculateAllocation(input);

        uint256 sum;
        for (uint8 i = 0; i < results.length; i++) {
            sum += results[i];
        }

        assertEq(sum, 100_00);
        assertEq(results[0], 2269);
        assertEq(results[1], 2720);
        assertEq(results[2], 5011);
    }

    function test_exponentialAllocationProvider() public {
        address[] memory strategies = new address[](3);
        strategies[0] = strategy1;
        strategies[1] = strategy2;
        strategies[2] = strategy3;

        int256[] memory apys = new int256[](3);
        apys[0] = apy_strategy1;
        apys[1] = apy_strategy2;
        apys[2] = apy_strategy3;

        FixedRM rm = new FixedRM();
        AllocationCalculationInput memory input =
            AllocationCalculationInput(strategies, apys, rm.getRiskScores(riskProvider, strategies), riskTolerance);

        IAllocationProvider ap = new ExponentialAllocationProvider();

        uint256[] memory results = ap.calculateAllocation(input);

        // reverts with invalid apy list length
        input.apys = new int256[](0);
        vm.expectRevert(abi.encodeWithSelector(ApysOrRiskScoresLengthMismatch.selector, 0, 3));
        ap.calculateAllocation(input);

        uint256 sum;
        for (uint8 i = 0; i < results.length; i++) {
            sum += results[i];
        }

        assertEq(sum, 100_00);
        assertEq(results[0], 167);
        assertEq(results[1], 174);
        assertEq(results[2], 9659);
    }
}
