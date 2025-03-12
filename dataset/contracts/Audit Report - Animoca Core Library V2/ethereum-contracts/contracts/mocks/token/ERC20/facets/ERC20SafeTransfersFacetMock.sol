// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IForwarderRegistry} from "./../../../../metatx/interfaces/IForwarderRegistry.sol";
import {ERC20SafeTransfersFacet} from "./../../../../token/ERC20/facets/ERC20SafeTransfersFacet.sol";

contract ERC20SafeTransfersFacetMock is ERC20SafeTransfersFacet {
    constructor(IForwarderRegistry forwarderRegistry) ERC20SafeTransfersFacet(forwarderRegistry) {}

    function __msgData() external view returns (bytes calldata) {
        return _msgData();
    }
}
