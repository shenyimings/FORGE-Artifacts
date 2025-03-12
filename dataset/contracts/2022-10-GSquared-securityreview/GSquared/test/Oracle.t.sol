// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.GSquared.t.sol";

contract RouterTest is Test, BaseSetup {
    using stdStorage for StdStorage;

    uint256 amount = 100E18;

    function testGetSwappingPrice() public {
        assertEq(curveOracle.getSwappingPrice(0, 1, amount, true), 100E18);
    }

    function testGetSinglePrice() public {
        uint256 vp = curveOracle.getVirtualPrice();
        assertEq(
            curveOracle.getSinglePrice(0, amount, true),
            (100E18 * vp) / 1E18
        );
    }

    function testGetTotalValue() public {
        uint256 vp = curveOracle.getVirtualPrice();
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 100E18;
        assertEq(curveOracle.getTotalValue(amounts), (100E18 * vp) / 1E18);
    }
}
