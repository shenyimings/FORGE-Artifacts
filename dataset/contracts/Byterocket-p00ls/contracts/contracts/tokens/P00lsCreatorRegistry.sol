// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces.sol";
import "./P00lsRegistryBase.sol";
import "./P00lsTokenCreator.sol";
import "./P00lsTokenXCreator.sol";
import "../utils/convert.sol";

/// @custom:security-contact security@p00ls.com
contract P00lsCreatorRegistry is P00lsRegistryBase {
    /**
     * Creator token creation
     */
    function createToken(
        address owner,
        string calldata name,
        string calldata symbol,
        string calldata xname,
        string calldata xsymbol,
        bytes32 root
    )
        external
        onlyRole(REGISTRY_MANAGER_ROLE)
        returns (address)
    {
        address creator  = _createProxy(beaconCreator());
        address xCreator = _createProxy(beaconXCreator());

        _mint(owner, addressToUint256(creator));

        P00lsTokenCreator(creator).initialize(
            name,
            symbol,
            root,
            xCreator
        );
        P00lsTokenXCreator(xCreator).initialize(
            xname,
            xsymbol,
            creator
        );

        return creator;
    }
}
