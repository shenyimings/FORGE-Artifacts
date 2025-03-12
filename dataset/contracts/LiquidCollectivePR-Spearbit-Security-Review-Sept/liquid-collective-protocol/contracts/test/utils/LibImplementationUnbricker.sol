// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import "forge-std/Test.sol";

library LibImplementationUnbricker {
    bytes32 public constant VERSION_SLOT = bytes32(uint256(keccak256("river.state.version")) - 1);

    function unbrick(Vm vm, address implem) internal {
        vm.store(implem, VERSION_SLOT, 0);
    }
}
