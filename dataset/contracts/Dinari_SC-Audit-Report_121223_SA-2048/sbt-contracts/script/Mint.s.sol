// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import "../src/IdShare.sol";

contract MintScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address[1] memory testWallets = [
            // add test wallets here
            address(0)
        ];

        address[1] memory mintAssets = [
            // 0x1ad40240395186ea900Cb3df6Bf5B64420CeA46D // fake USDC
            0x45bA256ED2F8225f1F18D76ba676C1373Ba7003F // new fake USDC
        ];

        for (uint256 i = 0; i < mintAssets.length; i++) {
            for (uint256 j = 0; j < testWallets.length; j++) {
                IdShare(mintAssets[i]).mint(testWallets[j], 10_000 ether);
            }
        }

        vm.stopBroadcast();
    }
}
