// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {dShare} from "../../../src/dShare.sol";
import {TransferRestrictor} from "../../../src/TransferRestrictor.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract MockdShareFactory {
    dShare public implementation;
    TransferRestrictor public transferRestrictor;
    UpgradeableBeacon public beacon;

    constructor() {
        implementation = new dShare();
        transferRestrictor = new TransferRestrictor(msg.sender);
        beacon = new UpgradeableBeacon(address(implementation), msg.sender);
    }

    function deploy(string memory name, string memory symbol) external returns (dShare) {
        return dShare(
            address(
                new BeaconProxy(address(beacon), abi.encodeCall(dShare.initialize, (msg.sender, name, symbol, transferRestrictor)))
            )
        );
    }
}
