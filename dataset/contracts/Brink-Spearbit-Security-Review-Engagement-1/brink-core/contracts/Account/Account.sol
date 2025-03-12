// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.10;
pragma abicoder v1;

import "../Proxy/ProxyGettable.sol";
import "./EIP712SignerRecovery.sol";
import "./EIP1271Validator.sol";

/// @title Brink account core
/// @notice Deployed once and used by many Proxy contracts as the implementation contract. External functions in this
/// contract are intended to be called only by `delegatecall` from other contracts.
contract Account is ProxyGettable, EIP712SignerRecovery, EIP1271Validator {
  /// @dev Revert if signer of a transaction or EIP712 message signer is not the proxy owner
  /// @param signer The address that is not the owner
  error NotOwner(address signer);

  /// @dev Revert if EIP1271 hash and signature is invalid
  /// @param hash Hash of the data to be validated
  /// @param signature Signature byte array associated with hash
  error InvalidSignature(bytes32 hash, bytes signature);

  /// @dev Revert if the Account.sol implementation contract is called directly
  error NotDelegateCall();

  /// @dev Typehash for signed metaDelegateCall() messages
  bytes32 internal immutable META_DELEGATE_CALL_TYPEHASH;

  /// @dev Typehash for signed metaDelegateCall_EIP1271() messages
  bytes32 internal immutable META_DELEGATE_CALL_EIP1271_TYPEHASH;

  /// @dev Deployment address of the implementation Account.sol contract. Used to enforce onlyDelegateCallable.
  address internal immutable deploymentAddress = address(this);

  /// @dev Used by external functions to revert if they are called directly on the implementation Account.sol contract
  modifier onlyDelegateCallable() {
    if (address(this) == deploymentAddress) {
      revert NotDelegateCall();
    }
    _;
  }

  /// @dev Constructor sets immutable constants
  constructor() { 
    META_DELEGATE_CALL_TYPEHASH = keccak256("MetaDelegateCall(address to,bytes data)");
    META_DELEGATE_CALL_EIP1271_TYPEHASH = keccak256("MetaDelegateCall_EIP1271(address to,bytes data)");
  }

  /// @dev Loads bytes32 data stored at the given pointer
  /// @param ptr The pointer to the bytes32 data
  function storageLoad(bytes32 ptr) external view returns (bytes32 data) {
    assembly { data := sload(ptr) }
  }

  /// @dev Makes a call to an external contract
  /// @dev Only executable directly by the proxy owner
  /// @param value Amount of wei to send with the call
  /// @param to Address of the external contract to call
  /// @param data Call data to execute
  function externalCall(uint256 value, address to, bytes memory data) external payable onlyDelegateCallable {
    if (proxyOwner() != msg.sender) {
      revert NotOwner(msg.sender);
    }

    assembly {
      let result := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /// @dev Makes a delegatecall to an external contract
  /// @param to Address of the external contract to delegatecall
  /// @param data Call data to execute
  function delegateCall(address to, bytes memory data) external payable onlyDelegateCallable {
    if (proxyOwner() != msg.sender) {
      revert NotOwner(msg.sender);
    }

    assembly {
      let result := delegatecall(gas(), to, add(data, 0x20), mload(data), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /// @dev Allows execution of a delegatecall with a valid signature from the proxyOwner. Uses EIP-712
  /// (https://github.com/ethereum/EIPs/pull/712) signer recovery.
  /// @param to Address of the external contract to delegatecall, signed by the proxyOwner
  /// @param data Call data to include in the delegatecall, signed by the proxyOwner
  /// @param signature Signature of the proxyOwner
  /// @param unsignedData Unsigned call data appended to the delegatecall
  /// @notice WARNING: The `to` contract is responsible for secure handling of the call provided in the encoded
  /// `callData`. If the proxyOwner signs a delegatecall to a malicious contract, this could result in total loss of
  /// their account.
  function metaDelegateCall(
    address to, bytes calldata data, bytes calldata signature, bytes calldata unsignedData
  ) external payable onlyDelegateCallable {
    address signer = _recoverSigner(
      keccak256(abi.encode(META_DELEGATE_CALL_TYPEHASH, to, keccak256(data))),
      signature
    );
    if (proxyOwner() != signer) {
      revert NotOwner(signer);
    }

    bytes memory callData = abi.encodePacked(data, unsignedData);

    assembly {
      let result := delegatecall(gas(), to, add(callData, 0x20), mload(callData), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /// @dev Allows execution of a delegatecall if proxyOwner is a smart contract. Uses EIP-1271
  /// (https://eips.ethereum.org/EIPS/eip-1271) signer validation.
  /// @param to Address of the external contract to delegatecall, validated by the proxyOwner contract
  /// @param data Call data to include in the delegatecall, validated by the proxyOwner contract
  /// @param signature Signature that will be validated by the proxyOwner contract
  /// @param unsignedData Unsigned call data appended to the delegatecall
  /// @notice WARNING: The `to` contract is responsible for secure handling of the call provided in the encoded
  /// `callData`. If the proxyOwner contract validates a delegatecall to a malicious contract, this could result in
  /// total loss of the account.
  function metaDelegateCall_EIP1271(
    address to, bytes calldata data, bytes calldata signature, bytes calldata unsignedData
  ) external payable onlyDelegateCallable {
    bytes32 hash = keccak256(abi.encode(META_DELEGATE_CALL_EIP1271_TYPEHASH, to, keccak256(data)));
    if(!_isValidSignature(proxyOwner(), hash, signature)) {
      revert InvalidSignature(hash, signature);
    }

    bytes memory callData = abi.encodePacked(data, unsignedData);

    assembly {
      let result := delegatecall(gas(), to, add(callData, 0x20), mload(callData), 0, 0)
      returndatacopy(0, 0, returndatasize())
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}
