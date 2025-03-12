// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";

contract TransferAllScript is Script {
    // When new issuers have been deployed, this script will add tokens to them.
    function run() external {
        uint256 senderKey = vm.envUint("SENDER_KEY");
        address to = vm.envAddress("TO");

        uint256 txCost = 100_000_000 * 470_000; // 0.1 gwei * estimated gas for script

        vm.startBroadcast(senderKey);

        uint256 balance = vm.addr(senderKey).balance;
        console.log("balance: %s", balance);
        (bool success,) = payable(to).call{value: balance - txCost}("");
        console.log("success: %s", success);
        // console.log("data: %s", data);

        vm.stopBroadcast();
    }
}
