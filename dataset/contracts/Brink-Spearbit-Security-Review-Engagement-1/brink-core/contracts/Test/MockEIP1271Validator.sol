// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

contract ISignatureValidatorConstants {
  // bytes4(keccak256("isValidSignature(bytes,bytes)")
  bytes4 internal constant EIP1271_MAGIC_VALUE = 0x20c13b0b;
}

abstract contract ISignatureValidator is ISignatureValidatorConstants {
  function isValidSignature(bytes memory _data, bytes memory _signature) public view virtual returns (bytes4);
}

/// implements some very basic EIP1271 validation for use in tests. Testing it with the backward compat pattern
/// that GnosisSafe is using just to be extra sure that our Account implementation of EIP1271 checks is compatible.
/// (https://github.com/gnosis/safe-contracts/blob/main/contracts/handler/CompatibilityFallbackHandler.sol)
contract MockEIP1271Validator is ISignatureValidator {
  bytes4 internal constant UPDATED_MAGIC_VALUE = 0x1626ba7e;

  mapping(bytes32 => bool) _validDataHash;
  mapping(bytes32 => bool) _validSigHashes;

  function isValidSignature(bytes calldata _data, bytes calldata _signature) public view override returns (bytes4) {
    if (_validDataHash[keccak256(_data)] == true && _validSigHashes[keccak256(_signature)] == true) {
      return EIP1271_MAGIC_VALUE;
    } else {
      return 0xffffffff;
    }
  }

  function isValidSignature(bytes32 _dataHash, bytes calldata _signature) public view returns (bytes4) {
    ISignatureValidator validator = ISignatureValidator(msg.sender);
    bytes4 value = validator.isValidSignature(abi.encode(_dataHash), _signature);
    return (value == EIP1271_MAGIC_VALUE) ? UPDATED_MAGIC_VALUE : bytes4(0);
  }

  function setValidSignature(bytes32 _dataHash, bytes calldata _signature) external {
    _validDataHash[keccak256(abi.encode(_dataHash))] = true;
    _validSigHashes[keccak256(_signature)] = true;
  }
}
