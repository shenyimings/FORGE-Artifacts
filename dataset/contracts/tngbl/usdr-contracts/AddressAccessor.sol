// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./AddressProvider.sol";

abstract contract AddressAccessor is AccessControl {
    AddressProvider public addressProvider;

    function setAddressProvider(AddressProvider _addressProvider)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        addressProvider = _addressProvider;
    }
}

abstract contract AddressAccessorUpgradable is AccessControlUpgradeable {
    AddressProvider public addressProvider;

    function setAddressProvider(AddressProvider _addressProvider)
        public
        virtual
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        addressProvider = _addressProvider;
    }
}
