// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract PortfolioAccessBaseUpgradeableCutted is OwnableUpgradeable {
    // solhint-disable-next-line
    function __PortfolioAccessBaseUpgradeableCutted_init()
        internal
        onlyInitializing
    {
        __Ownable_init();
    }

    address[] public unused;
}
