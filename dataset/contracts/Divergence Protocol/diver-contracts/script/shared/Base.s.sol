// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Script } from "forge-std/Script.sol";

contract BaseScript is Script {
    address internal deployer;
    string internal mnemonic;

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }

    function setUp() public virtual {
        mnemonic = vm.envString("MNEMONIC");
        // mnemonic = vm.envString(mne);
        (deployer,) = deriveRememberKey(mnemonic, 0);
    }
}
