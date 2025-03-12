// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";

contract TransferScript is Script {
    // When new issuers have been deployed, this script will add tokens to them.
    function run() external {
        uint256 senderKey = vm.envUint("SENDER_KEY");
        address to = vm.envAddress("TO");
        uint256 amount = vm.envUint("SEND_AMOUNT");

        vm.startBroadcast(senderKey);

        (bool success,) = payable(to).call{value: amount}("");
        console.log("success: %s", success);

        vm.stopBroadcast();
    }
}
