// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./ConicTest.sol";
import "../contracts/oracles/CurveLPOracle.sol";

import "../interfaces/vendor/ICurvePoolV0.sol";
import "../libraries/ScaledMath.sol";

contract CurveLPOracleTest is ConicTest {
    using ScaledMath for uint256;
    CurveLPOracle public curveLPOracle;
    GenericOracle public genericOracle;

    function setUp() public override {
        super.setUp();
        _setFork(mainnetFork);

        Controller controller = _createController(_getCNCToken(), _createRegistryCache());
        curveLPOracle = _createCurveLpOracle(controller);
        genericOracle = _createGenericOracle(address(curveLPOracle));
        CrvUsdOracle crvUsdOracle = new CrvUsdOracle(address(genericOracle));
        genericOracle.setCustomOracle(Tokens.CRV_USD, address(crvUsdOracle));
        controller.setPriceOracle(address(genericOracle));
    }

    function testGetPrice() public {
        uint256 triPoolPrice = curveLPOracle.getUSDPrice(Tokens.TRI_POOL_LP);
        uint256 expected = ICurvePoolV0(CurvePools.TRI_POOL).get_virtual_price();
        assertApproxEqRel(expected, triPoolPrice, 0.01e18, "TRI_POOL_LP");

        uint256 stethPoolPrice = curveLPOracle.getUSDPrice(Tokens.STETH_ETH_LP);
        uint256 ethPrice = genericOracle.getUSDPrice(Tokens.WETH);
        expected = ethPrice.mulDown(ICurvePoolV0(CurvePools.STETH_ETH_POOL).get_virtual_price());
        assertApproxEqRel(expected, stethPoolPrice, 0.01e18, "STETH_ETH_POOL_LP");
    }

    function testWorksForAllLPTokens() public {
        address[] memory tokens = new address[](13);

        // generated from [p.allCurvePools() for p in controller.listAllPools()]
        tokens[0] = 0x06325440D014e39736583c165C2963BA99fAf14E;
        tokens[1] = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC;
        tokens[2] = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
        tokens[3] = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
        tokens[4] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
        tokens[5] = 0x0CD6f267b2086bea681E922E19D40512511BE538;
        tokens[6] = 0x5b6C539b224014A09B3388e51CaAA8e354c959C8;
        tokens[7] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4;
        tokens[8] = 0xFC2838a17D8e8B1D5456E0a351B0708a09211147;
        tokens[9] = 0xCa978A0528116DDA3cbA9ACD3e68bc6191CA53D0;
        tokens[10] = 0xC25a3A3b969415c80451098fa907EC722572917F;
        tokens[11] = 0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C;
        tokens[12] = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B;

        for (uint256 i; i < tokens.length; i++) {
            uint256 price = curveLPOracle.getUSDPrice(tokens[i]);
            assertGt(price, 0, "price should be greater than 0");
        }
    }
}
