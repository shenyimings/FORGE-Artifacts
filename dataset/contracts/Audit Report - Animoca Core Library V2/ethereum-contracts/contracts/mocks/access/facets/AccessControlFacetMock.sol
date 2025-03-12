// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {AccessControlStorage} from "./../../../access/libraries/AccessControlStorage.sol";
import {AccessControlFacet} from "./../../../access/facets/AccessControlFacet.sol";

contract AccessControlFacetMock is AccessControlFacet {
    using AccessControlStorage for AccessControlStorage.Layout;

    bytes32 public constant TEST_ROLE = "tester";

    constructor(IForwarderRegistry forwarderRegistry) AccessControlFacet(forwarderRegistry) {}

    function enforceHasRole(bytes32 role, address account) external view {
        AccessControlStorage.layout().enforceHasRole(role, account);
    }

    function enforceHasTargetContractRole(address targetContract, bytes32 role, address account) external view {
        AccessControlStorage.enforceHasTargetContractRole(targetContract, role, account);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
