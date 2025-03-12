// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract NFTFactory is Initializable, OwnableUpgradeable {
    event BeaconCreated(address beaconAddress, string beaconType);
    event Deployed(address tokenAddress);
    mapping(string => address) public beacons;

    function initialize() public initializer {
        __Ownable_init();
    }

    function setBeacon(string memory beaconType, address implementation_, address upgrader_) external onlyOwner returns (address) {
        beacons[beaconType] = _newBeacon(beaconType, implementation_, upgrader_);
        return beacons[beaconType];
    }

    function _newBeacon(string memory beaconType, address implementation_, address upgrader_) private returns (address) {
        UpgradeableBeacon beacon = new UpgradeableBeacon(implementation_);
        beacon.transferOwnership(upgrader_);
        emit BeaconCreated(address(beacon), beaconType);
        return address(beacon);
    }

    function createProxy(string memory beaconType, bytes calldata data_) external onlyOwner returns (address) {
        require(beacons[beaconType] != address(0));

        BeaconProxy proxy = new BeaconProxy(
            beacons[beaconType],
            data_
        );
        emit Deployed(address(proxy));
        return address(proxy);
    }
}
