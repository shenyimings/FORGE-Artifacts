// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/ethRome/PeanutETHRome.sol";

contract DeployEthRome is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = 0x6B3751c5b04Aa818EA90115AA06a4D9A36A16f02;
        vm.startBroadcast(deployerPrivateKey);

        // Create new PeanutETHRome contract
        PeanutETHRome peanutETHRome = new PeanutETHRome();

        // Mint 250 tokens to the owner's address
        uint256 numTokens = 250;
        peanutETHRome.batchMint(deployerAddress, numTokens);

        vm.stopBroadcast();

        // Log contract address
        console.log("Contract address: %s", address(peanutETHRome));
    }
}
