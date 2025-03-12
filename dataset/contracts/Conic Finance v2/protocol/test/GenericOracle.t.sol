// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicPoolBaseTest.sol";
import "../interfaces/vendor/IBooster.sol";
import "../interfaces/IOracle.sol";

contract GenericOracleTest is ConicPoolBaseTest {
    IOracle public oracle;

    function setUp() public override {
        super.setUp();
        oracle = IOracle(controller.priceOracle());
    }

    function testGenericOracle() public {
        assertEq(oracle.isTokenSupported(Tokens.ST_ETH), true);
        assertEq(oracle.isTokenSupported(Tokens.CBETH), true);
        assertEq(oracle.isTokenSupported(Tokens.RETH), true);

        uint256 ethPrice = oracle.getUSDPrice(address(0));
        assertApproxEqRel(oracle.getUSDPrice(Tokens.WETH), ethPrice, 0.1e18, "WETH");
        assertApproxEqRel(oracle.getUSDPrice(Tokens.ST_ETH), ethPrice, 0.1e18, "STETH_ETH");
        assertApproxEqRel(oracle.getUSDPrice(Tokens.CBETH), ethPrice, 0.1e18, "CBETH_ETH");
        assertApproxEqRel(oracle.getUSDPrice(Tokens.RETH), ethPrice, 0.1e18, "RETH_ETH");
    }
}
