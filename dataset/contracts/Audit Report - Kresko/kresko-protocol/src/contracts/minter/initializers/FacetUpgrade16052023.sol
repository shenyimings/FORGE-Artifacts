// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.20;

import {ms} from "../MinterStorage.sol";
import {CollateralAsset} from "../MinterTypes.sol";
import {AggregatorV2V3Interface} from "../../vendor/flux/FluxPriceFeed.sol";

/* solhint-disable var-name-mixedcase */
interface NewKresko {
    function collateralAsset(address) external view returns (CollateralAsset memory);
}

interface OldKresko {
    struct CollateralOld {
        uint256 factor;
        AggregatorV2V3Interface oracle;
        AggregatorV2V3Interface marketStatusOracle;
        address anchor;
        uint8 decimals;
        bool exists;
    }

    function collateralAsset(address) external view returns (CollateralOld memory);
}

contract FacetUpgrade16052023 {
    function initialize() external {
        ms().initializations += 1;
        address DAI = 0x7ff84e6d3111327ED63eb97691Bf469C7fcE832F;
        address WETH = 0x4200000000000000000000000000000000000006;
        address krBTC = 0xf88721B9C87EBc86E3C91E6C98c0f646a75600f4;
        address krETH = 0xbb37d6016f97Dd369eCB76e2A5036DacD8770f8b;
        address krTSLA = 0x3502B0329a45011C8FEE033B8eEe6BDA89c03081;
        address KISS = 0xC0B5aBa9F46bDf4D1bC52a4C3ab05C857aC4Ee80;
        address[] memory collateralAssets = new address[](6);
        collateralAssets[0] = DAI;
        collateralAssets[1] = WETH;
        collateralAssets[2] = krBTC;
        collateralAssets[3] = krETH;
        collateralAssets[4] = krTSLA;
        collateralAssets[5] = KISS;
        for (uint i = 0; i < collateralAssets.length; i++) {
            address asset = collateralAssets[i];
            ms().collateralAssets[asset].liquidationIncentive = 1.05 ether;
        }

        require(ms().collateralAssets[DAI].exists, "!found");
        require(ms().collateralAssets[WETH].liquidationIncentive == 1.05 ether, "!config");

        uint256 liqIncentive = NewKresko(0x0921a7234a2762aaB3C43d3b1F51dB5D8094a04b)
            .collateralAsset(krBTC)
            .liquidationIncentive;
        require(liqIncentive == 1.05 ether, "!found-new");
    }
}
