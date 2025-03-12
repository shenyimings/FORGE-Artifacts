// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./CurveParams.sol";

// Libraries
import "../src/Curve.sol";
import "../src/Config.sol";

// Factories
import "../src/CurveFactoryV2.sol";

// Zap
import "../src/Zap.sol";
import "../src/Router.sol";
import "./Addresses.sol";
import "../src/interfaces/IERC20Detailed.sol";

// POLYGON DEPLOYMENT
contract ContractScript is Script {
    function run() external {
        address OWNER = 0x1246E96b7BC94107aa10a08C3CE3aEcc8E19217B;
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // // first deploy the config
        // int128 protocolFee = 50_000;
        // Config config = new Config(protocolFee, OWNER);

        // // Deploy Assimilator
        // AssimilatorFactory deployedAssimFactory = new AssimilatorFactory(
        //     address(config)
        // );

        // // Deploy CurveFactoryV2
        // address wMatic = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        // CurveFactoryV2 deployedCurveFactory = new CurveFactoryV2(
        //     address(deployedAssimFactory),
        //     address(config),
        //     wMatic
        // );

        // // Attach CurveFactoryV2 to Assimilator
        // deployedAssimFactory.setCurveFactory(address(deployedCurveFactory));

        // // deploy usdc-cadc, cadc-wmatic, cadc-eurs, sgd-link

        // IOracle usdOracle = IOracle(Polygon.CHAINLINK_USDC_USD);
        // IOracle cadOracle = IOracle(Polygon.CHAINLINK_CAD_USD);
        // IOracle eurOracle = IOracle(Polygon.CHAINLINK_EUR_USD);
        // IOracle sgdOracle = IOracle(Polygon.CHAINLINK_SGD_USD);
        // IOracle linkOracle = IOracle(
        //     0xd9FFdb71EbE7496cC440152d43986Aae0AB76665
        // );
        // IOracle wethOracle = IOracle(
        //     0xAB594600376Ec9fD91F8e885dADF0CE036862dE0
        // );

        // address LINK = 0x53E0bca35eC356BD5ddDFebbD1Fc0fD03FaBad39;
        // address WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

        // CurveInfo memory cadcUsdcCurveInfo = CurveInfo(
        //     "dfx-cadc-usdc-v2.5",
        //     "dfx-cadc-usdc-v2.5",
        //     Polygon.CADC,
        //     Polygon.USDC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     cadOracle,
        //     usdOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Polygon.CADC_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory cadcMaticCurveInfo = CurveInfo(
        //     "dfx-cadc-matic-v2.5",
        //     "dfx-cadc-matic-v2.5",
        //     Polygon.CADC,
        //     WMATIC,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     cadOracle,
        //     wethOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Polygon.EURS_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory cadcEursCurveInfo = CurveInfo(
        //     "dfx-cadc-eurs-v2.5",
        //     "dfx-cadc-eurs-v2.5",
        //     Polygon.CADC,
        //     Polygon.EURS,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     cadOracle,
        //     eurOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Polygon.XSGD_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // CurveInfo memory sgdLinkCurveInfo = CurveInfo(
        //     "dfx-xsgd-link-v2",
        //     "dfx-xsgd-link-v2",
        //     Polygon.XSGD,
        //     LINK,
        //     CurveParams.BASE_WEIGHT,
        //     CurveParams.QUOTE_WEIGHT,
        //     sgdOracle,
        //     linkOracle,
        //     CurveParams.ALPHA,
        //     CurveParams.BETA,
        //     CurveParams.MAX,
        //     Polygon.NZDS_EPSILON,
        //     CurveParams.LAMBDA
        // );

        // // Deploy all new Curves
        // deployedCurveFactory.newCurve(cadcUsdcCurveInfo);
        // deployedCurveFactory.newCurve(cadcMaticCurveInfo);
        // deployedCurveFactory.newCurve(cadcEursCurveInfo);
        // deployedCurveFactory.newCurve(sgdLinkCurveInfo);
        // Zap zap = new Zap(address(deployedCurveFactory));
        Router router = new Router(0x869AD45F0051979232c99dD5d4B7B9603A5080E0);
        vm.stopBroadcast();
    }
}
