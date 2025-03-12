// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./TransparentUpgradeableProxy.sol";

contract Proxyadmin is ProxyAdmin {

    function submitTimelockUpgrade(TransparentUpgradeableproxy proxy ,uint256 newTimelock) public onlyOwner {
        proxy.submitNewTimelock(newTimelock);
    }

    /**
     * @dev Upgrades `proxy` to `implementation`. See {TransparentUpgradeableProxy-upgradeTo}.
     *
     * Requirements:
     *
     * - This contract must be the admin of `proxy`.
     */
    function upgradeTimelock(TransparentUpgradeableproxy proxy)
        public
        virtual
        onlyOwner
    {
        proxy.changeTimelock();
    }

    function submitUpgrade(TransparentUpgradeableproxy proxy ,address newImplementation) public onlyOwner {
        proxy.submitUpgrade(newImplementation);
    }

}