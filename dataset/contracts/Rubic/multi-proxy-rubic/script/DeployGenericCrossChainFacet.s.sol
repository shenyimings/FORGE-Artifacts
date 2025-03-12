// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { GenericCrossChainFacet } from "rubic/Facets/GenericCrossChainFacet.sol";

contract DeployScript is DeployScriptBase {
    constructor() DeployScriptBase("GenericCrossChainFacet") {}

    function run() public returns (GenericCrossChainFacet deployed) {
        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return GenericCrossChainFacet(predicted);
        }

        deployed = GenericCrossChainFacet(
            factory.deploy(salt, type(GenericCrossChainFacet).creationCode)
        );

        vm.stopBroadcast();
    }
}
