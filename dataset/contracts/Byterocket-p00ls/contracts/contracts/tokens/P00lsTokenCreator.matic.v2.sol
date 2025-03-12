// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./P00lsTokenCreator.matic.sol";

/// @custom:security-contact security@p00ls.com
/// @custom:oz-upgrades-from P00lsTokenCreator_Polygon
contract P00lsTokenCreator_Polygon_V2 is P00lsTokenCreator_Polygon
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address registry) P00lsTokenCreator_Polygon(registry) {}

    // Admin gets the whitelister role
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override
        returns (bool)
    {
        return super.hasRole(role, account)
            || (role == WHITELISTER && account == admin());
    }
}
