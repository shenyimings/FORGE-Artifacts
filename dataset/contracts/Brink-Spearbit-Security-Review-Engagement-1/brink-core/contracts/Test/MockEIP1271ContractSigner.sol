// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

/// similar to https://github.com/gnosis/safe-contracts/blob/main/contracts/base/FallbackManager.sol to make sure the
/// Account contract's EIP1271 implementation will work with a GnosisSafe
contract MockEIP1271ContractSigner {
  // keccak256("fallback_manager.handler.address")
  bytes32 internal constant FALLBACK_HANDLER_STORAGE_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;

  function setFallbackHandler(address handler) public {
    bytes32 slot = FALLBACK_HANDLER_STORAGE_SLOT;
    assembly {
      sstore(slot, handler)
    }
  }

  fallback() external {
    bytes32 slot = FALLBACK_HANDLER_STORAGE_SLOT;
    assembly {
      let handler := sload(slot)
      if iszero(handler) {
        return(0, 0)
      }
      calldatacopy(0, 0, calldatasize())
      // The msg.sender address is shifted to the left by 12 bytes to remove the padding
      // Then the address without padding is stored right after the calldata
      mstore(calldatasize(), shl(96, caller()))
      // Add 20 bytes for the address appended add the end
      let success := call(gas(), handler, 0, 0, add(calldatasize(), 20), 0, 0)
      returndatacopy(0, 0, returndatasize())
      if iszero(success) {
        revert(0, returndatasize())
      }
      return(0, returndatasize())
    }
  }
}
