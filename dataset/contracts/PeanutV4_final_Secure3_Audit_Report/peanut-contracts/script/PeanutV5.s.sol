// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/V5/PeanutV5.sol";
import "./DeploymentGlobals.sol";

contract DeployScript is Script, DeploymentGlobals {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Define the salt for CREATE2
        bytes32 salt = keccak256(abi.encodePacked("Some unique string"));

        // Compute the target address
        // TODO: fix this (addresses don't align)
        address targetAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(type(PeanutV5).creationCode))
                    )
                )
            )
        );
        console.log("target address: %s", address(targetAddress));

        address ecoAddress = ecoAddressByChain[block.chainid];

        // Deploy the contract using CREATE2
        PeanutV5 peanutV5 = new PeanutV5{salt: salt}(ecoAddress);
        // PeanutV5 peanutV5 = new PeanutV5();

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("contract address: %s", address(peanutV5));
    }
}
