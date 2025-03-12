// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../metatx/interfaces/IForwarderRegistry.sol";
import {ContractOwnershipStorage} from "./../../../access/libraries/ContractOwnershipStorage.sol";
import {ContractOwnershipFacet} from "./../../../access/facets/ContractOwnershipFacet.sol";

contract ContractOwnershipFacetMock is ContractOwnershipFacet {
    using ContractOwnershipStorage for ContractOwnershipStorage.Layout;

    constructor(IForwarderRegistry forwarderRegistry) ContractOwnershipFacet(forwarderRegistry) {}

    function enforceIsContractOwner(address account) external view {
        ContractOwnershipStorage.layout().enforceIsContractOwner(account);
    }

    function enforceIsTargetContractOwner(address targetContract, address account) external view {
        ContractOwnershipStorage.enforceIsTargetContractOwner(targetContract, account);
    }

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
