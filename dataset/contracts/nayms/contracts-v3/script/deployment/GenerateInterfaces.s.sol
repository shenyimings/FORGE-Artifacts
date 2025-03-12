// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9;

import "script/utils/DeploymentHelpers.sol";
import "script/utils/LibGeneratedNaymsFacetHelpers.sol";

contract GenerateInterfaces is DeploymentHelpers {
    function run(string memory pathToOutput, string memory solVersion) external {
        if (keccak256(abi.encodePacked(pathToOutput)) == keccak256(abi.encodePacked(""))) {
            pathToOutput = "test-interfaces";
        }
        string[] memory facetNames = LibGeneratedNaymsFacetHelpers.getFacetNames();

        string memory artifactFile;
        string memory outputPathAndName;

        string memory interfaceName;
        string[] memory inputs = new string[](9);
        inputs[0] = "cast";
        inputs[1] = "interface";
        inputs[2] = artifactFile;
        inputs[3] = "-o";
        inputs[4] = outputPathAndName;
        inputs[5] = "-n";
        inputs[7] = "-p";
        inputs[8] = solVersion;

        for (uint256 i; i < facetNames.length; i++) {
            artifactFile = string.concat(artifactsPath, facetNames[i], "Facet.sol/", facetNames[i], "Facet.json");
            outputPathAndName = string.concat(pathToOutput, "/I", facetNames[i], "Facet.sol");
            interfaceName = string.concat("I", facetNames[i], "Facet");
            inputs[2] = artifactFile;
            inputs[4] = outputPathAndName;
            inputs[6] = interfaceName;
            bytes memory res = vm.ffi(inputs);
        }

        console2.log("Number of facets: ", facetNames.length);
    }
}
