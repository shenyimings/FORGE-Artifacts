// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "solady/test/utils/mocks/MockERC20.sol";
import {FeeLib} from "../../src/common/FeeLib.sol";

contract FeeLibTest is Test {
    MockERC20 usdc;

    function setUp() public {
        usdc = new MockERC20("USD Coin", "USDC", 6);
    }

    function testUSDCFlatFee() public {
        // 1 USDC flat fee
        uint256 flatFee = wrapFlatFeeForOrder(address(usdc), 1 ether);
        assertEq(flatFee, 1e6);
    }

    function wrapFlatFeeForOrder(address newToken, uint64 perOrderFee) public view returns (uint256) {
        return FeeLib.flatFeeForOrder(newToken, perOrderFee);
    }
}
