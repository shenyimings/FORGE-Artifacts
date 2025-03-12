// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicPoolBaseTest.sol";
import "../contracts/oracles/CrvUsdOracle.sol";

contract CrvUsdOracleTest is ConicPoolBaseTest {
    IOracle public crvUsdOracle;

    function setUp() public override {
        super.setUp();
        _setFork(mainnetFork);
        address genericOracle = address(controller.priceOracle());
        crvUsdOracle = IOracle(address(new CrvUsdOracle(genericOracle)));
    }

    function testTokensSupported() public {
        assertTrue(crvUsdOracle.isTokenSupported(Tokens.CRV_USD));
        assertFalse(crvUsdOracle.isTokenSupported(Tokens.WETH));
        assertFalse(crvUsdOracle.isTokenSupported(Tokens.USDC));
    }

    function testPrice() public {
        uint256 crvUsdPrice = crvUsdOracle.getUSDPrice(Tokens.CRV_USD);
        assertApproxEqRel(crvUsdPrice, 1e18, 0.05e18, "CRV_USD");
    }
}
