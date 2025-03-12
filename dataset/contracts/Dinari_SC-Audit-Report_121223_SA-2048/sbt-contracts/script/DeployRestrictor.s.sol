// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {dShare} from "../src/dShare.sol";

contract DeployRestrictorScript is Script {
    // When new issuers have been deployed, this script will add tokens to them.
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("RESTRICTOR");

        address[13] memory assetTokens = [
            0xa40c0975607BDbF7B868755E352570454b5B2e48,
            0xf67e6E9a4B62accd0Aa9DD113a7ef8a0653Bb9Cb,
            0xFdC642c9B59189710D0cac0528D2791968cf560a,
            0x6AE848Cd367aC2559abC06BdbD33bEed6B2f49d5,
            0x20f11c1aBca831E235B15A4714b544Bb968f8CDF,
            0x5a8A18673aDAA0Cd1101Eb4738C05cc6967b860f,
            0x9bd7A08cD17d10E02F596Aa760dfE397C57668b4,
            0x58A8eeC9b82CdF13090A2032235Beb9152e7eB3b,
            0x70732186F811f205c28C583096C8ae861B359CEf,
            0x1ba13cD81B018e06d7a7EaD033D5131115fE6C82,
            0x9F1f1B79163dABeDe8227429588289218A832359,
            0x2888c0aC959484e53bBC6CdaBf2b8b39486225C6,
            0x2414faE77CF726cC2287B81cf174d9828adc6636
        ];

        vm.startBroadcast(deployerPrivateKey);

        // deploy new restrictor
        TransferRestrictor restrictor = new TransferRestrictor(owner);

        // replace old restrictor
        for (uint256 i = 0; i < assetTokens.length; i++) {
            dShare assetToken = dShare(assetTokens[i]);
            assetToken.setTransferRestrictor(restrictor);
        }

        vm.stopBroadcast();
    }
}
