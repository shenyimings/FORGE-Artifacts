// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Scripting tool
import {Script} from "../lib/forge-std/src/Script.sol";

// Core contracts
import {LooksRareProtocol} from "../contracts/LooksRareProtocol.sol";

contract AddAffiliate is Script {
    error ChainIdInvalid(uint256 chainId);

    function run() external {
        uint256 chainId = block.chainid;

        if (chainId != 5) {
            revert ChainIdInvalid(chainId);
        }

        uint256 deployerPrivateKey = vm.envUint("TESTNET_KEY");
        LooksRareProtocol looksRareProtocol = LooksRareProtocol(0x35C2215F2FFe8917B06454eEEaba189877F200cf);

        vm.startBroadcast(deployerPrivateKey);

        looksRareProtocol.updateAffiliateRate(0xdb5Ac292C5a3749e1feDc330294acBa7272294ce, 2_500);

        vm.stopBroadcast();
    }
}
