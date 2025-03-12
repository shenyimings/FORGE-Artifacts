// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13 <0.9;

import "forge-std/console2.sol";
import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "script/utils/LibWriteJson.sol";
import { strings } from "lib/solidity-stringutils/src/strings.sol";
import "solmate/utils/CREATE3.sol";
import "./LibGeneratedNaymsFacetHelpers.sol";
import { INayms, IDiamondCut, IDiamondLoupe } from "src/diamonds/nayms/INayms.sol";

/// @notice helper methods to deploy a diamond,

interface IInitDiamond {
    function initialize() external;
}

contract DeploymentHelpers is Test {
    using stdJson for *;
    using strings for *;
    using stdStorage for StdStorage;

    string public constant artifactsPath = "forge-artifacts/";
    // File that is being parsed for the diamond address. If we are deploying a new diamond, then the address will be overwritten here.
    string public deployFile = "deployedAddresses.json";

    address internal sDiamondAddress;

    IDiamondCut.FacetCut[] public cutS;

    bytes4[] public replaceSelectors;
    bytes4[] public addSelectors;
    bytes4[] public removeSelectors;

    enum FacetDeploymentAction {
        DeployAllFacets,
        UpgradeFacetsWithChangesOnly,
        UpgradeFacetsListedOnly
    }

    struct MethodId1 {
        string sig1;
    }

    struct MethodId2 {
        string sig1;
        string sig2;
    }

    struct MethodId3 {
        string sig1;
        string sig2;
        string sig3;
    }

    struct MethodId4 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
    }

    struct MethodId5 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
    }

    struct MethodId6 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
    }

    struct MethodId7 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
    }

    struct MethodId8 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
    }

    struct MethodId9 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
    }

    struct MethodId10 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
    }

    struct MethodId11 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
    }

    struct MethodId12 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
    }

    struct MethodId13 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
    }

    struct MethodId14 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
    }

    struct MethodId15 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
    }

    struct MethodId16 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
    }

    struct MethodId17 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
        string sig17;
    }

    struct MethodId18 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
        string sig17;
        string sig18;
    }

    struct MethodId19 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
        string sig17;
        string sig18;
        string sig19;
    }

    struct MethodId20 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
        string sig17;
        string sig18;
        string sig19;
        string sig20;
    }

    struct MethodId21 {
        string sig1;
        string sig2;
        string sig3;
        string sig4;
        string sig5;
        string sig6;
        string sig7;
        string sig8;
        string sig9;
        string sig10;
        string sig11;
        string sig12;
        string sig13;
        string sig14;
        string sig15;
        string sig16;
        string sig17;
        string sig18;
        string sig19;
        string sig20;
        string sig21;
    }

    function removeFromArray(uint256 index) public {
        console2.log(string.concat("removeFromArray index: ", vm.toString(index), ". removeSelectors.length: ", vm.toString(removeSelectors.length)));
        require(removeSelectors.length > index, "Out of bounds");
        // move all elements to the left, starting from the `index + 1`
        for (uint256 i = index; i < removeSelectors.length - 1; i++) {
            removeSelectors[i] = removeSelectors[i + 1];
        }
        removeSelectors.pop(); // delete the last item
    }

    function getDiamondAddressFromFile() internal returns (address diamondAddress) {
        // Read in current diamond address
        string memory deployData = vm.readFile(deployFile);

        string memory key = string.concat(".NaymsDiamond.", vm.toString(block.chainid));
        bytes memory parsed = vm.parseJson(deployData, key);
        diamondAddress = abi.decode(parsed, (address));
    }

    function getFacetNameFromFacetAddress() internal returns (string memory facetName) {}

    function deployDeterministically() internal returns (address) {
        // // deterministically deploy Nayms diamond
        // console2.log("Deterministic contract address for Nayms", CREATE3.getDeployed(salt));
        // naymsAddress = CREATE3.getDeployed(salt);
        // vm.label(CREATE3.getDeployed(salt), "Nayms Diamond");
        // nayms = INayms(CREATE3.deploy(salt, abi.encodePacked(type(Nayms).creationCode, abi.encode(account0)), 0));
        // assertEq(naymsAddress, CREATE3.getDeployed(salt));
    }

    // true: deploys a new diamond, writes to deployFile
    // false: reads deployFile .NaymsDiamond
    function diamondDeployment(bool deployNewDiamond) public returns (address naymsDiamondAddress) {
        if (deployNewDiamond) {
            // string memory contractName = "Nayms";
            // string memory artifactFile = string.concat(artifactsPath, contractName, ".sol/", contractName, ".json");

            // Deploy new Diamond
            // bytes memory args = abi.encode(msg.sender);
            // naymsDiamondAddress = deployCode(artifactFile, args);

            naymsDiamondAddress = LibGeneratedNaymsFacetHelpers.deployNaymsFacetsByName("Nayms");
            vm.label(address(naymsDiamondAddress), "New Nayms Diamond");

            // Output diamond address

            // string memory write = LibWriteJson.createObject(
            //     LibWriteJson.keyObject(
            //         "NaymsDiamond",
            //         LibWriteJson.keyObject(vm.toString(block.chainid), LibWriteJson.keyValue("address", vm.toString(address(naymsDiamondAddress))))
            //     )
            // );
            // solhint-disable quotes
            vm.removeFile(deployFile);
            vm.writeLine(deployFile, '{ "NaymsDiamond": { ');

            string memory d = string.concat('"', vm.toString(block.chainid), '": { "address": "', vm.toString(naymsDiamondAddress), '" } ');
            vm.writeLine(deployFile, d);

            if (block.chainid != 31337) {
                string memory d31337 = string.concat(', "31337": { "address": "0xAe2Df030C2184a369B8a4F6fA4d3CB19Fbe55955" } ');
                vm.writeLine(deployFile, d31337);
            }

            vm.writeLine(deployFile, "}}");
        } else {
            // Read in current diamond address
            naymsDiamondAddress = getDiamondAddressFromFile();

            // todo label with an additional identifier, such as timestamp or package version number?
            vm.label(address(naymsDiamondAddress), "Same Nayms Diamond");
        }

        // store diamond address to be used later to create output
        sDiamondAddress = naymsDiamondAddress;
    }

    function findAndReplace(bytes memory res, string memory find) public view returns (string[] memory parts) {
        string memory start = string(res);
        strings.slice memory s = start.toSlice();
        string memory d = find;
        strings.slice memory delim = d.toSlice();
        s.count(delim);
        parts = new string[](s.count(delim) + 1);
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();

            console2.log(parts[i]);
        }
    }

    function findAndReplaceToString(bytes memory res, string memory find) public view returns (string memory whole) {
        string memory start = string(res);
        strings.slice memory s = start.toSlice();
        string memory d = find;
        strings.slice memory delim = d.toSlice();
        s.count(delim);
        string[] memory parts = new string[](s.count(delim) + 1);

        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();

            whole = string.concat(whole, parts[i]);
            console2.log(parts[i]);
            console2.log(whole);
        }
    }

    function replaceNewLineWithComma(bytes memory res) public view returns (string[] memory parts) {
        string memory start = string(res);
        strings.slice memory s = start.toSlice();
        string memory d = "\n";
        strings.slice memory delim = d.toSlice();
        s.count(delim);
        parts = new string[](s.count(delim) + 1);
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = s.split(delim).toString();

            console2.log(parts[i]);
        }
    }

    function deployContract(string memory contractName) public returns (address contractAddress) {
        string memory artifactFile = string.concat(artifactsPath, contractName, ".sol/", contractName, ".json");

        contractAddress = deployCode(artifactFile);
    }

    function deploySelectFacet(string memory facetName) public returns (address facetAddress) {
        string memory artifactFile = string.concat(artifactsPath, facetName, "Facet.sol/", facetName, "Facet.json");

        facetAddress = deployCode(artifactFile);
        console2.log("deploySelectFacet facet address", facetAddress);
    }

    /**
     * @notice Compares the bytecode in the artifact to the matching onchain facet bytecode .
     * @dev This method returns true for matching bytecode.
     */
    function compareBytecode(address diamondAddress, string memory facetName) public returns (bool bytecodeMatchFlag) {
        // read the newly compiled artifact file for the facet
        string memory artifactFile = string.concat(artifactsPath, facetName, "Facet.sol/", facetName, "Facet.json");
        string memory artifactData = vm.readFile(artifactFile);

        bytes memory bytecode = vm.parseJson(artifactData, ".deployedBytecode.object");
        bytes memory bytecodeDecoded = abi.decode(bytecode, (bytes));

        (uint256 numberOfFunctionSignaturesFromArtifact, bytes4[] memory functionSignatures) = getFunctionSignaturesFromArtifact(facetName);

        // get first non zero address
        address targetFacetAddress;
        for (uint256 i; i < numberOfFunctionSignaturesFromArtifact; i++) {
            targetFacetAddress = IDiamondLoupe(diamondAddress).facetAddress(functionSignatures[i]);
            if (targetFacetAddress != address(0)) {
                break;
            }
        }

        bytes memory targetFacetBytecode = targetFacetAddress.code;
        bytecodeMatchFlag = checkEq0(targetFacetBytecode, bytecodeDecoded);
    }

    function getFunctionSignaturesFromArtifact(string memory facetName) public returns (uint256 numberOfFunctionSignaturesFromArtifact, bytes4[] memory functionSelectors) {
        string memory artifactFile = string.concat(artifactsPath, facetName, "Facet.sol/", facetName, "Facet.json");
        string memory artifactData = vm.readFile(artifactFile);
        bytes memory parsedArtifactData = vm.parseJson(artifactData, ".methodIdentifiers");

        // todo rename for clarity,
        numberOfFunctionSignaturesFromArtifact = parsedArtifactData.length / 32;

        if (numberOfFunctionSignaturesFromArtifact == 4) {
            MethodId1 memory decodedData = abi.decode(parsedArtifactData, (MethodId1));

            functionSelectors = new bytes4[](1);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 1) {
            MethodId2 memory decodedData = abi.decode(parsedArtifactData, (MethodId2));

            functionSelectors = new bytes4[](2);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 2) {
            MethodId3 memory decodedData = abi.decode(parsedArtifactData, (MethodId3));

            functionSelectors = new bytes4[](3);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 3) {
            MethodId4 memory decodedData = abi.decode(parsedArtifactData, (MethodId4));

            functionSelectors = new bytes4[](4);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 4) {
            MethodId5 memory decodedData = abi.decode(parsedArtifactData, (MethodId5));

            functionSelectors = new bytes4[](5);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 5) {
            MethodId6 memory decodedData = abi.decode(parsedArtifactData, (MethodId6));

            functionSelectors = new bytes4[](6);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 6) {
            MethodId7 memory decodedData = abi.decode(parsedArtifactData, (MethodId7));

            functionSelectors = new bytes4[](7);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 7) {
            MethodId8 memory decodedData = abi.decode(parsedArtifactData, (MethodId8));

            functionSelectors = new bytes4[](8);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 8) {
            MethodId9 memory decodedData = abi.decode(parsedArtifactData, (MethodId9));

            functionSelectors = new bytes4[](9);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 9) {
            MethodId10 memory decodedData = abi.decode(parsedArtifactData, (MethodId10));

            functionSelectors = new bytes4[](10);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 10) {
            MethodId11 memory decodedData = abi.decode(parsedArtifactData, (MethodId11));

            functionSelectors = new bytes4[](11);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 11) {
            MethodId12 memory decodedData = abi.decode(parsedArtifactData, (MethodId12));

            functionSelectors = new bytes4[](12);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 12) {
            MethodId13 memory decodedData = abi.decode(parsedArtifactData, (MethodId13));

            functionSelectors = new bytes4[](13);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 13) {
            MethodId14 memory decodedData = abi.decode(parsedArtifactData, (MethodId14));

            functionSelectors = new bytes4[](14);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 14) {
            MethodId15 memory decodedData = abi.decode(parsedArtifactData, (MethodId15));

            functionSelectors = new bytes4[](15);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 15) {
            MethodId16 memory decodedData = abi.decode(parsedArtifactData, (MethodId16));

            functionSelectors = new bytes4[](16);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 16) {
            MethodId17 memory decodedData = abi.decode(parsedArtifactData, (MethodId17));

            functionSelectors = new bytes4[](17);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
            functionSelectors[16] = bytes4(vm.parseBytes(decodedData.sig17));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 17) {
            MethodId18 memory decodedData = abi.decode(parsedArtifactData, (MethodId18));

            functionSelectors = new bytes4[](18);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
            functionSelectors[16] = bytes4(vm.parseBytes(decodedData.sig17));
            functionSelectors[17] = bytes4(vm.parseBytes(decodedData.sig18));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 18) {
            MethodId19 memory decodedData = abi.decode(parsedArtifactData, (MethodId19));

            functionSelectors = new bytes4[](19);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
            functionSelectors[16] = bytes4(vm.parseBytes(decodedData.sig17));
            functionSelectors[17] = bytes4(vm.parseBytes(decodedData.sig18));
            functionSelectors[18] = bytes4(vm.parseBytes(decodedData.sig19));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 19) {
            MethodId20 memory decodedData = abi.decode(parsedArtifactData, (MethodId20));

            functionSelectors = new bytes4[](20);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
            functionSelectors[16] = bytes4(vm.parseBytes(decodedData.sig17));
            functionSelectors[17] = bytes4(vm.parseBytes(decodedData.sig18));
            functionSelectors[18] = bytes4(vm.parseBytes(decodedData.sig19));
            functionSelectors[19] = bytes4(vm.parseBytes(decodedData.sig20));
        } else if (numberOfFunctionSignaturesFromArtifact == 4 + 3 * 20) {
            MethodId21 memory decodedData = abi.decode(parsedArtifactData, (MethodId21));

            functionSelectors = new bytes4[](21);
            functionSelectors[0] = bytes4(vm.parseBytes(decodedData.sig1));
            functionSelectors[1] = bytes4(vm.parseBytes(decodedData.sig2));
            functionSelectors[2] = bytes4(vm.parseBytes(decodedData.sig3));
            functionSelectors[3] = bytes4(vm.parseBytes(decodedData.sig4));
            functionSelectors[4] = bytes4(vm.parseBytes(decodedData.sig5));
            functionSelectors[5] = bytes4(vm.parseBytes(decodedData.sig6));
            functionSelectors[6] = bytes4(vm.parseBytes(decodedData.sig7));
            functionSelectors[7] = bytes4(vm.parseBytes(decodedData.sig8));
            functionSelectors[8] = bytes4(vm.parseBytes(decodedData.sig9));
            functionSelectors[9] = bytes4(vm.parseBytes(decodedData.sig10));
            functionSelectors[10] = bytes4(vm.parseBytes(decodedData.sig11));
            functionSelectors[11] = bytes4(vm.parseBytes(decodedData.sig12));
            functionSelectors[12] = bytes4(vm.parseBytes(decodedData.sig13));
            functionSelectors[13] = bytes4(vm.parseBytes(decodedData.sig14));
            functionSelectors[14] = bytes4(vm.parseBytes(decodedData.sig15));
            functionSelectors[15] = bytes4(vm.parseBytes(decodedData.sig16));
            functionSelectors[16] = bytes4(vm.parseBytes(decodedData.sig17));
            functionSelectors[17] = bytes4(vm.parseBytes(decodedData.sig18));
            functionSelectors[18] = bytes4(vm.parseBytes(decodedData.sig19));
            functionSelectors[19] = bytes4(vm.parseBytes(decodedData.sig20));
            functionSelectors[20] = bytes4(vm.parseBytes(decodedData.sig21));
        }

        numberOfFunctionSignaturesFromArtifact = functionSelectors.length;
    }

    /**
     * @notice Deploys a new facet by its name (calling deploySelectFacet()) and creates the Cut struct
     */
    function deployFacetAndCreateFacetCut(string memory facetName) public returns (IDiamondCut.FacetCut memory cut) {
        cut.facetAddress = deploySelectFacet(facetName);

        (, cut.functionSelectors) = getFunctionSignaturesFromArtifact(facetName);

        cut.action = IDiamondCut.FacetCutAction.Add;
    }

    /**
     * @notice OLD WAY TO MAKE COVERAGE WORK. Deploys a new facet by its name (calling deploySelectFacet()) and creates the Cut struct
     */

    function deployFacetAndCreateFacetCutOLD(string memory facetName) public returns (IDiamondCut.FacetCut memory cut) {
        cut.facetAddress = LibGeneratedNaymsFacetHelpers.deployNaymsFacetsByName(facetName);

        (, cut.functionSelectors) = getFunctionSignaturesFromArtifact(facetName);

        cut.action = IDiamondCut.FacetCutAction.Add;
    }

    /**
     * @notice Pass in the facet deployment pattern that is desired. The various facet deployment patterns are explained in the FacetDeploymentAction enum.
     */
    function facetDeploymentAndCut(
        address diamondAddress,
        FacetDeploymentAction facetDeploymentAction,
        string[] memory facetsToCutIn
    ) public returns (IDiamondCut.FacetCut[] memory cut) {
        // If deployAllFacets == true, then deploy all of the facets currently defined
        // If deployAllFacets == false, then only upgrade the facets listed in the array facetsToCutIn
        // deployAllFacets == false

        string[] memory allFacetNames = LibGeneratedNaymsFacetHelpers.getFacetNames();
        uint256 numberOfFacets = allFacetNames.length;

        if (facetDeploymentAction == FacetDeploymentAction.DeployAllFacets) {
            // loop through allFacetNames and deploy them
            // note this purely adds all facet methods.
            cut = new IDiamondCut.FacetCut[](numberOfFacets);
            for (uint256 i; i < numberOfFacets; i++) {
                // note: bring this back once coverage covers deployments from bytecode
                // cut[i] = deployFacetAndCreateFacetCut(allFacetNames[i]);
                cut[i] = deployFacetAndCreateFacetCutOLD(allFacetNames[i]);
            }
        } else if (facetDeploymentAction == FacetDeploymentAction.UpgradeFacetsWithChangesOnly) {
            // V1: check if facet bytecode is different. If so, then deploy facet and add, remove, replace methods.
            // loop through allFacetNames
            // check if function sig exists

            for (uint256 i; i < numberOfFacets; i++) {
                if (!compareBytecode(diamondAddress, allFacetNames[i])) {
                    dynamicFacetCutV1(diamondAddress, allFacetNames[i]);
                }
            }

            cut = cutS;
        } else if (facetDeploymentAction == FacetDeploymentAction.UpgradeFacetsListedOnly) {
            // Deploy the facets listed in facetsToCutIn
            require(facetsToCutIn.length > 0, "facetDeployment: did not provide any facet names to be manually deployed");

            for (uint256 i; i < facetsToCutIn.length; i++) {
                dynamicFacetCutV1(diamondAddress, facetsToCutIn[i]);
            }

            cut = cutS;
        }
    }

    /// Adds any new function sigs. Replaces any functions with the same sig. Removes any functions that don't exist in the new facet.
    /// @notice V1 of dynamic facet cuts. If the facet has a new method, then the facet will be newly deployed and cut in
    // If the facet has a method with the same function sig

    /**
     * @dev If the facet only has methods with the same function sig (no new function sigs), then this method is not smart enough
     * to know whether or not there's a change in the function itself to warrent a new deployment / diamond cut.
     * This extra smartness will come in V2 of dynamicFacetCut() :)
     * @param diamondAddress The address of the diamond to be upgraded. note: The diamond must have the standard diamond loupe functions
     * @param facetName Name of the facet to cut in
     */
    function dynamicFacetCutV1(address diamondAddress, string memory facetName) public returns (IDiamondCut.FacetCut[] memory cut) {
        // if it already exists - replace
        // if it doesn't exist in the old facet - add
        // if it doesn't exist in the new facet and it doesn't exist in the old facet - remove

        uint256 replaceCount;
        uint256 addCount;
        uint256 removeCount;

        address oldFacetAddress;

        (uint256 numFunctionSelectors, bytes4[] memory functionSelectors) = getFunctionSignaturesFromArtifact(facetName);
        console2.log("numFunctionSelectors - dynamicFacetCutV1()", numFunctionSelectors);
        console2.log(facetName);
        // REPLACE, ADD (remove is after REPLACE and ADD)
        if (numFunctionSelectors > 0) {
            for (uint256 i; i < numFunctionSelectors; ++i) {
                // replace "old" method with "new" method
                if (IDiamondLoupe(diamondAddress).facetAddress(functionSelectors[i]) != address(0)) {
                    replaceCount++;

                    replaceSelectors.push(functionSelectors[i]);

                    // assume the old facet address is the address with a matching function selector - todo make this more robust
                    oldFacetAddress = IDiamondLoupe(diamondAddress).facetAddress(functionSelectors[i]);
                    // add method if it doesn't exist in the old facet
                } else if (IDiamondLoupe(diamondAddress).facetAddress(functionSelectors[i]) == address(0)) {
                    addCount++;
                    addSelectors.push(functionSelectors[i]);
                }
            }
        }

        // REMOVE
        // if there are selectors in the old facet that are not being replaced, then they should be removed, since they are not in the new facet
        // from the list of selectors from the old facet, remove from the list the selectors that are being replaced.
        uint256 numberOfSelectorsFromOldFacet;
        // bytes4[] memory removeSelectors;
        if (oldFacetAddress != address(0)) {
            bytes4[] memory oldFacetSelectors = IDiamondLoupe(diamondAddress).facetFunctionSelectors(oldFacetAddress);
            numberOfSelectorsFromOldFacet = oldFacetSelectors.length;
            for (uint256 i; i < numberOfSelectorsFromOldFacet; i++) {
                address facetAddress = IDiamondLoupe(diamondAddress).facetAddress(oldFacetSelectors[i]);
            }

            // get list of selectors in "current" facet
            removeSelectors = IDiamondLoupe(diamondAddress).facetFunctionSelectors(oldFacetAddress);
            uint256 oldFacetCount = removeSelectors.length;
            for (uint256 q; q < removeSelectors.length; q++) {
                console2.log(string.concat(facetName, vm.toString(removeSelectors[q])));
            }

            uint256 numSelectorsRemovedFromFacet;

            for (uint256 k; k < oldFacetCount; k++) {
                for (uint256 j; j < numFunctionSelectors; j++) {
                    // compare list of old selectors with list of new selectors, if any are the same, then remove from the list of old selectors (removeSelectors[])
                    if (removeSelectors[k - numSelectorsRemovedFromFacet] == functionSelectors[j] && removeSelectors[k - numSelectorsRemovedFromFacet] != 0) {
                        console2.log(string.concat("selector from removeSelectors array: ", vm.toString(removeSelectors[k - numSelectorsRemovedFromFacet])));
                        console2.log(string.concat("selector from functionSelectors array: ", vm.toString(functionSelectors[j])));
                        removeFromArray(k - numSelectorsRemovedFromFacet);
                        numSelectorsRemovedFromFacet++;
                        break;
                    }
                }
            }
        }

        removeCount = removeSelectors.length;

        // deploy a new facet if it's needed
        address newFacetAddress;

        if (addCount != 0 || replaceCount != 0) {
            newFacetAddress = deploySelectFacet(facetName);
        }

        if (addCount > 0 && replaceCount > 0 && removeCount > 0) {
            cut = new IDiamondCut.FacetCut[](3);

            cut[0] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors });
            cut[1] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors });
            cut[2] = IDiamondCut.FacetCut({ facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: removeSelectors });
            cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors }));
            cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors }));
            cutS.push(IDiamondCut.FacetCut({ facetAddress: address(0), action: IDiamondCut.FacetCutAction.Remove, functionSelectors: removeSelectors }));
            console2.log("adding functions:");
            for (uint256 a; a < addCount; a++) {
                console2.log(string.concat(facetName, vm.toString(addSelectors[a])));
            }
            console2.log("replacing functions:");
            for (uint256 r; r < replaceCount; r++) {
                console2.log(string.concat(facetName, vm.toString(replaceSelectors[r])));
            }
            console2.log("removing functions:");
            for (uint256 q; q < removeCount; q++) {
                console2.log(string.concat(facetName, vm.toString(removeSelectors[q])));

                if (removeSelectors[q] == bytes4(0)) {
                    console2.log("reverted because selector is 0x");
                    revert();
                }
            }
        } else if (addCount > 0 && replaceCount > 0) {
            cut = new IDiamondCut.FacetCut[](2);

            cut[0] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors });
            cut[1] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors });
            cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors }));
            cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors }));
        } else {
            cut = new IDiamondCut.FacetCut[](1);
            if (addCount > 0) {
                cut[0] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors });
                cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Add, functionSelectors: addSelectors }));
            } else if (replaceCount > 0) {
                cut[0] = IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors });
                cutS.push(IDiamondCut.FacetCut({ facetAddress: address(newFacetAddress), action: IDiamondCut.FacetCutAction.Replace, functionSelectors: replaceSelectors }));
            }
        }

        // clear out storage arrays. Otherwise, these storage arrays will retain the state from the first iteration of this method which is not desired for a subsequent call.
        delete replaceSelectors;
        delete addSelectors;
        delete removeSelectors;
    }

    function cutAndInit(
        address diamondAddress,
        IDiamondCut.FacetCut[] memory cut,
        address initAddress
    ) public {
        // todo check if init contract has initialize method
        // if the initAddress param is not null, then we assume to call initialize from the provided initAddress to "initialize" the diamond.
        if (initAddress != address(0)) {
            IInitDiamond initDiamond = IInitDiamond(initAddress);

            IDiamondCut(diamondAddress).diamondCut(cut, address(initAddress), abi.encodeCall(initDiamond.initialize, ()));
        } else {
            IDiamondCut(diamondAddress).diamondCut(cut, address(0), "");
        }
    }

    /**
     * @notice This method ties everything together
     * @param deployNewDiamond Flag: true: deploy a new diamond. false: use the current diamond.
     * @param initNewDiamond Flag: true: deploy InitDiamond and initialize the diamond. false: does not deploy InitDiamond and does not call initialize.
     * @param facetDeploymentAction DeployAllFacets - deploys all facets in the facets folder and cuts them in.
     * UpgradeFacetsWithChangesOnly - looks at bytecode, if there's a difference, then will deploy a new facet, run through dynamic deployment
     * UpgradeFacetsListedOnly - looks at facetsToCutIn and runs through dynamic deployment only on those facets
     * @param facetsToCutIn List facets to manually cut in
     * @return diamondAddress initDiamond
     */
    function smartDeployment(
        bool deployNewDiamond,
        bool initNewDiamond,
        FacetDeploymentAction facetDeploymentAction,
        string[] memory facetsToCutIn
    ) public returns (address diamondAddress, address initDiamond) {
        // deploys new Nayms diamond, or gets the diamond address from file
        diamondAddress = diamondDeployment(deployNewDiamond);

        // todo do we want to deploy a new init contract, or do we want to use the "current" init contract?
        if (initNewDiamond) {
            // initDiamond = deployContract("InitDiamond");
            initDiamond = LibGeneratedNaymsFacetHelpers.deployNaymsFacetsByName("InitDiamond");
        }
        // deploys facets
        IDiamondCut.FacetCut[] memory cut = facetDeploymentAndCut(diamondAddress, facetDeploymentAction, facetsToCutIn);

        debugDeployment(diamondAddress, facetsToCutIn, facetDeploymentAction);
        cutAndInit(diamondAddress, cut, initDiamond);
    }

    function debugDeployment(
        address diamondAddress,
        string[] memory facetsToCutIn,
        FacetDeploymentAction facetDeploymentAction
    ) internal {
        uint256 addCount;
        uint256 replaceCount;
        uint256 removeCount;
        console2.log("Remove selectors");
        for (uint256 i; i < cutS.length; i++) {
            if (cutS[i].action == IDiamondCut.FacetCutAction.Remove) {
                for (uint256 q; q < cutS[i].functionSelectors.length; q++) {
                    string memory out = string.concat(vm.toString(cutS[i].facetAddress), " ", vm.toString(cutS[i].functionSelectors[q]));
                    console2.log(out);
                    removeCount++;
                }
            }
        }
        console2.log("Add selectors");
        for (uint256 i; i < cutS.length; i++) {
            if (cutS[i].action == IDiamondCut.FacetCutAction.Add) {
                for (uint256 q; q < cutS[i].functionSelectors.length; q++) {
                    console2.logBytes4(cutS[i].functionSelectors[q]);
                    addCount++;
                }
            }
        }
        console2.log("Replace selectors");
        for (uint256 i; i < cutS.length; i++) {
            if (cutS[i].action == IDiamondCut.FacetCutAction.Replace) {
                for (uint256 q; q < cutS[i].functionSelectors.length; q++) {
                    address currentFacetAddress;
                    currentFacetAddress = IDiamondLoupe(diamondAddress).facetAddress(cutS[i].functionSelectors[q]);
                    string memory out = string.concat(
                        "new address: ",
                        vm.toString(cutS[i].facetAddress),
                        " old address: ",
                        vm.toString(currentFacetAddress),
                        " ",
                        vm.toString(cutS[i].functionSelectors[q])
                    );
                    console2.log(out);

                    console2.logBytes4(cutS[i].functionSelectors[q]);
                    replaceCount++;
                }
            }
        }

        if (facetDeploymentAction == FacetDeploymentAction.UpgradeFacetsListedOnly) {
            console2.log("num facets to cut in", facetsToCutIn.length);
        }

        console2.log("num remove", removeCount);

        console2.log("num add", addCount);
        console2.log("num replace", replaceCount);
        INayms nayms = INayms(diamondAddress);
        console2.log("contract owner", nayms.owner());
    }

    function updateDeployOutputName(string memory outputName) public {
        deployFile = outputName;
    }
}
