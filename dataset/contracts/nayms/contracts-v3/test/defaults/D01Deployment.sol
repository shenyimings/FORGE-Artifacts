// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import "./D00GlobalDefaults.sol";

import { InitDiamond } from "src/diamonds/nayms/InitDiamond.sol";
import { Nayms } from "src/diamonds/nayms/Nayms.sol";
import { INayms } from "src/diamonds/nayms/INayms.sol";
import { LibAdmin } from "src/diamonds/nayms/libs/LibAdmin.sol";
import { LibConstants } from "src/diamonds/nayms/libs/LibConstants.sol";
import { LibHelpers } from "src/diamonds/nayms/libs/LibHelpers.sol";
import { LibObject } from "src/diamonds/nayms/libs/LibObject.sol";

import { LibGeneratedNaymsFacetHelpers } from "script/utils/LibGeneratedNaymsFacetHelpers.sol";

// import { DeploymentHelpers } from "script/utils/DeploymentHelpers.sol";

/// @notice Default test setup part 01
///         Deploy and initialize Nayms platform
contract D01Deployment is
    D00GlobalDefaults /*, DeploymentHelpers*/
{
    address public naymsAddress;
    InitDiamond public initDiamond;

    INayms public nayms;

    //// test constant variables ////
    bytes32 public immutable salt = keccak256(bytes("A salt!"));

    function setUp() public virtual override {
        super.setUp();

        console2.log("\n -- D01 Deployment  \n");
        // string[] memory facetsToCutIn;

        // deployFile = "deployedAddressesTest.json";
        // vm.startPrank(msg.sender);
        // (naymsAddress, ) = smartDeployment(true, true, FacetDeploymentAction.DeployAllFacets, facetsToCutIn);
        // vm.stopPrank();
        // nayms = INayms(naymsAddress);

        // deploy the init contract
        initDiamond = new InitDiamond();

        // deploy all facets
        address[] memory naymsFacetAddresses = LibGeneratedNaymsFacetHelpers.deployNaymsFacets();

        // deterministically deploy Nayms diamond
        nayms = INayms(address(new Nayms(address(this))));

        naymsAddress = address(nayms);
        // initialize the diamond as well as cut in all facets
        INayms.FacetCut[] memory cut = LibGeneratedNaymsFacetHelpers.createNaymsDiamondFunctionsCut(naymsFacetAddresses);

        // vm.prank(msg.sender);
        nayms.diamondCut(cut, address(initDiamond), abi.encodeCall(initDiamond.initialize, ()));
    }
}
