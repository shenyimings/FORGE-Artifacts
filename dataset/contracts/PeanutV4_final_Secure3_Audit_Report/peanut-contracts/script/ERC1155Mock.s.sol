// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/util/ERC1155Mock.sol";

contract DeployERC1155MockScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Create new ERC1155Mock contract (with broadcast enabled this will send the tx to mempool)
        ERC1155Mock erc1155Mock = new ERC1155Mock();

        vm.stopBroadcast();

        // do something for no unused variable warning (log contract address)
        console.log("ERC1155Mock contract address: %s", address(erc1155Mock));
    }
}
