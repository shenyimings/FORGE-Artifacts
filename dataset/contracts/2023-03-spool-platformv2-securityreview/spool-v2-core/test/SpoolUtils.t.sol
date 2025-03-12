// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SpoolUtils} from "../src/libraries/SpoolUtils.sol";
import {IStrategy} from "../src/interfaces/IStrategy.sol";
import {IStrategyRegistry} from "../src/interfaces/IStrategyRegistry.sol";
import {IUsdPriceFeedManager} from "../src/interfaces/IUsdPriceFeedManager.sol";
import {Arrays} from "./libraries/Arrays.sol";

contract SpoolUtilsTest is Test {
    function setUp() public {}

    function test_getStrategyRatiosAtLastDhw_shouldReturnForOneStrategy() public {
        IStrategyRegistry strategyRegistry = IStrategyRegistry(address(0x1));

        uint256[][] memory expected = new uint256[][](1);
        expected[0] = Arrays.toArray(1, 2);

        address[] memory strategies = Arrays.toArray(address(0xa));

        for (uint256 i = 0; i < strategies.length; ++i) {
            vm.mockCall(
                address(strategyRegistry),
                abi.encodeWithSelector(IStrategyRegistry.assetRatioAtLastDhw.selector, strategies[i]),
                abi.encode(expected[i])
            );
        }

        uint256[][] memory strategyRatios = SpoolUtils.getStrategyRatiosAtLastDhw(strategies, strategyRegistry);

        assertEq(strategyRatios.length, expected.length);
        for (uint256 i = 0; i < strategyRatios.length; ++i) {
            assertEq(strategyRatios[i], expected[i]);
        }
    }

    function test_getStrategyRatiosAtLastDhw_shouldReturnForMultipleStrategies() public {
        IStrategyRegistry strategyRegistry = IStrategyRegistry(address(0x1));

        uint256[][] memory expected = new uint256[][](3);
        expected[0] = Arrays.toArray(1, 2);
        expected[1] = Arrays.toArray(3);
        expected[2] = Arrays.toArray(4, 5, 6);

        address[] memory strategies = Arrays.toArray(address(0xa), address(0xb), address(0xc));

        for (uint256 i = 0; i < expected.length; ++i) {
            vm.mockCall(
                address(strategyRegistry),
                abi.encodeWithSelector(IStrategyRegistry.assetRatioAtLastDhw.selector, strategies[i]),
                abi.encode(expected[i])
            );
        }

        uint256[][] memory strategyRatios = SpoolUtils.getStrategyRatiosAtLastDhw(strategies, strategyRegistry);

        assertEq(expected.length, expected.length);
        for (uint256 i = 0; i < strategyRatios.length; ++i) {
            assertEq(strategyRatios[i], expected[i]);
        }
    }

    function test_getExchangeRates_shouldGiveExchangeRatesForSingleToken() public {
        IUsdPriceFeedManager priceFeedManager = IUsdPriceFeedManager(address(0x1));

        uint256[] memory expected = Arrays.toArray(1200_00000000000000000000000000);

        address[] memory tokens = Arrays.toArray(address(0xa));
        uint256[] memory decimals = Arrays.toArray(18);

        for (uint256 i = 0; i < expected.length; ++i) {
            vm.mockCall(
                address(priceFeedManager),
                abi.encodeWithSelector(IUsdPriceFeedManager.assetDecimals.selector, tokens[i]),
                abi.encode(decimals[i])
            );

            vm.mockCall(
                address(priceFeedManager),
                abi.encodeWithSelector(IUsdPriceFeedManager.assetToUsd.selector, tokens[i]),
                abi.encode(expected[i])
            );
        }

        uint256[] memory exchangeRates = SpoolUtils.getExchangeRates(tokens, priceFeedManager);

        assertEq(exchangeRates, expected);
    }

    function test_getExchangeRates_shouldGiveExchangeRatesForMultipleTokens() public {
        IUsdPriceFeedManager priceFeedManager = IUsdPriceFeedManager(address(0x1));

        uint256[] memory expected = Arrays.toArray(
            1200_00000000000000000000000000, 280_00000000000000000000000000, 16000_00000000000000000000000000
        );

        address[] memory tokens = Arrays.toArray(address(0xa), address(0xb), address(0xc));
        uint256[] memory decimals = Arrays.toArray(18, 6, 18);

        for (uint256 i = 0; i < expected.length; ++i) {
            vm.mockCall(
                address(priceFeedManager),
                abi.encodeWithSelector(IUsdPriceFeedManager.assetDecimals.selector, tokens[i]),
                abi.encode(decimals[i])
            );

            vm.mockCall(
                address(priceFeedManager),
                abi.encodeWithSelector(IUsdPriceFeedManager.assetToUsd.selector, tokens[i]),
                abi.encode(expected[i])
            );
        }

        uint256[] memory exchangeRates = SpoolUtils.getExchangeRates(tokens, priceFeedManager);

        assertEq(exchangeRates, expected);
    }

    function test_getVaultTotalUsdValue_shouldGetValueForOneStrategy() public {
        address[] memory strategies = Arrays.toArray(address(0xa));
        uint256[] memory totalStrategyValues = Arrays.toArray(1000000);
        uint256[] memory strategyVaultBalances = Arrays.toArray(1000000);
        uint256[] memory strategySupplies = Arrays.toArray(2000000);

        for (uint256 i = 0; i < strategies.length; ++i) {
            vm.mockCall(
                strategies[i],
                abi.encodeWithSelector(IStrategy.totalUsdValue.selector),
                abi.encode(totalStrategyValues[i])
            );

            vm.mockCall(
                strategies[i], abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(strategyVaultBalances[i])
            );

            vm.mockCall(
                strategies[i], abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(strategySupplies[i])
            );
        }

        uint256 totalValue = SpoolUtils.getVaultTotalUsdValue(address(0x1), strategies);
        assertEq(totalValue, 500000);
    }

    function test_getVaultTotalUsdValue_shouldGetValueForMultipleStrategies() public {
        address[] memory strategies = Arrays.toArray(address(0xa), address(0xb), address(0xc));
        uint256[] memory totalStrategyValues = Arrays.toArray(1000000, 100000, 10000);
        uint256[] memory strategyVaultBalances = Arrays.toArray(1000000, 200000, 40000);
        uint256[] memory strategySupplies = Arrays.toArray(2000000, 400000, 80000);

        for (uint256 i = 0; i < strategies.length; ++i) {
            vm.mockCall(
                strategies[i],
                abi.encodeWithSelector(IStrategy.totalUsdValue.selector),
                abi.encode(totalStrategyValues[i])
            );

            vm.mockCall(
                strategies[i], abi.encodeWithSelector(IERC20.balanceOf.selector), abi.encode(strategyVaultBalances[i])
            );

            vm.mockCall(
                strategies[i], abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(strategySupplies[i])
            );
        }

        uint256 totalValue = SpoolUtils.getVaultTotalUsdValue(address(0x1), strategies);

        assertEq(totalValue, 555000);
    }

    // TODO: test limit values for getVaultTotalUsdValue

    function test_getRevertMsg_shouldGetDefaultMessageWhenNoRevertMessage() public {
        RevertingContract revertingContract = new RevertingContract();

        (bool success, bytes memory data) =
            address(revertingContract).call(abi.encodeWithSelector(RevertingContract.revertWithNoMessage.selector));

        assertFalse(success);

        string memory message = SpoolUtils.getRevertMsg(data);
        vm.expectRevert("SmartVaultManager::_getRevertMsg: Transaction reverted silently.");
        revert(message);
    }

    function test_getRevertMsg_shouldGetOriginalMessageWhenRevertMessage() public {
        RevertingContract revertingContract = new RevertingContract();

        (bool success, bytes memory data) =
            address(revertingContract).call(abi.encodeWithSelector(RevertingContract.revertWithMessage.selector));

        assertFalse(success);

        string memory message = SpoolUtils.getRevertMsg(data);
        vm.expectRevert("I reverted.");
        revert(message);
    }

    // TODO: check this
    // reverts with: vm.expectRevert("SmartVaultManager::_getRevertMsg: Transaction reverted silently.");
    // function test_getRevertMsg_shouldGetCustomErrorWhenRevertingWithCustomErrorA() public {
    //     RevertingContract revertingContract = new RevertingContract();

    //     (bool success, bytes memory data) = address(revertingContract).call(abi.encodeWithSelector(RevertingContract.revertWithCustomErrorA.selector));

    //     assertFalse(success);

    //     string memory message = SpoolUtils.getRevertMsg(data);
    //     vm.expectRevert(abi.encodeWithSelector(CustomErrorA.selector));
    //     revert(message);
    // }

    // reverts with: vm.expectRevert("I reverted B.");
    // function test_getRevertMsg_shouldGetCustomErrorWhenRevertingWithCustomErrorB() public {
    //     RevertingContract revertingContract = new RevertingContract();

    //     (bool success, bytes memory data) = address(revertingContract).call(abi.encodeWithSelector(RevertingContract.revertWithCustomErrorB.selector));

    //     assertFalse(success);

    //     string memory message = SpoolUtils.getRevertMsg(data);
    //     vm.expectRevert(abi.encodeWithSelector(CustomErrorB.selector, "I reverted B."));
    //     revert(message);
    // }

    // reverts with: vm.expectRevert("SmartVaultManager::_getRevertMsg: Transaction reverted silently.");
    // function test_getRevertMsg_shouldGetCustomErrorWhenRevertingWithCustomErrorC() public {
    //     RevertingContract revertingContract = new RevertingContract();

    //     (bool success, bytes memory data) = address(revertingContract).call(abi.encodeWithSelector(RevertingContract.revertWithCustomErrorC.selector));

    //     assertFalse(success);

    //     string memory message = SpoolUtils.getRevertMsg(data);
    //     vm.expectRevert(abi.encodeWithSelector(CustomErrorC.selector, 5));
    //     revert(message);
    // }
}

error CustomErrorA();
error CustomErrorB(string message);
error CustomErrorC(uint256 id);

contract RevertingContract {
    function test_mock() external pure {}

    function revertWithNoMessage() external pure {
        revert();
    }

    function revertWithMessage() external pure {
        revert("I reverted.");
    }

    function revertWithCustomErrorA() external pure {
        revert CustomErrorA();
    }

    function revertWithCustomErrorB() external pure {
        revert CustomErrorB("I reverted B.");
    }

    function revertWithCustomErrorC() external pure {
        revert CustomErrorC(5);
    }
}
