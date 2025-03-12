// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployScriptBase } from "./utils/DeployScriptBase.sol";
import { stdJson } from "forge-std/Script.sol";
import { RubicMultiProxy } from "rubic/RubicMultiProxy.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    constructor() DeployScriptBase("RubicMultiProxy") {}

    function run()
        public
        returns (RubicMultiProxy deployed, bytes memory constructorArgs)
    {
        string memory path = string.concat(
            root,
            "/deployments/",
            network,
            ".",
            fileSuffix,
            "json"
        );
        string memory json = vm.readFile(path);
        address diamondCut = json.readAddress(".DiamondCutFacet");
        address erc20proxy = json.readAddress(".ERC20Proxy");

        constructorArgs = abi.encode(deployerAddress, diamondCut, erc20proxy);

        vm.startBroadcast(deployerPrivateKey);

        if (isDeployed()) {
            return (RubicMultiProxy(payable(predicted)), constructorArgs);
        }

        deployed = RubicMultiProxy(
            payable(
                factory.deploy(
                    salt,
                    bytes.concat(
                        type(RubicMultiProxy).creationCode,
                        constructorArgs
                    )
                )
            )
        );

        vm.stopBroadcast();
    }
}
