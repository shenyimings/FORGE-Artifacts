// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/DepositSwap.sol";
import "../src/interfaces/IAssetGroupRegistry.sol";
import "../src/interfaces/ISmartVaultManager.sol";
import "../src/interfaces/ISwapper.sol";
import "./libraries/Arrays.sol";

contract DepositSwapTest is Test {
    IWETH9 weth;

    function setUp() public {
        weth = IWETH9(address(0x1));
    }

    function test_swapAndDeposit_shouldRevertWhenArraysMissmatch() public {
        DepositSwap depositSwap = new DepositSwap(
            weth,
            IAssetGroupRegistry(address(0x1)),
            ISmartVaultManager(address(0x2)),
            ISwapper(address(0x3))
        );

        address[] memory inTokens = Arrays.toArray(address(0x4), address(0x5));
        uint256[] memory inAmounts = Arrays.toArray(1);

        vm.expectRevert(InvalidArrayLength.selector);
        depositSwap.swapAndDeposit(inTokens, inAmounts, new SwapInfo[](0), address(0x6), address(0xa));

        inTokens = Arrays.toArray(address(0x4));
        inAmounts = Arrays.toArray(1, 2);

        vm.expectRevert(InvalidArrayLength.selector);
        depositSwap.swapAndDeposit(inTokens, inAmounts, new SwapInfo[](0), address(0x6), address(0xa));
    }
}
