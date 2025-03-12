// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ActionInfo} from "src/lib/Structs.sol";

contract LlamaCoreSigUtils {
  struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
  }

  struct CreateAction {
    address tokenHolder;
    uint8 role;
    address strategy;
    address target;
    uint256 value;
    bytes data;
    string description;
    uint256 nonce;
  }

  struct CancelAction {
    address tokenHolder;
    ActionInfo actionInfo;
    uint256 nonce;
  }

  struct CastVote {
    address tokenHolder;
    uint8 role;
    ActionInfo actionInfo;
    uint8 support;
    string reason;
    uint256 nonce;
  }

  struct CastVeto {
    address tokenHolder;
    uint8 role;
    ActionInfo actionInfo;
    uint8 support;
    string reason;
    uint256 nonce;
  }

  /// @notice EIP-712 base typehash.
  bytes32 internal constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

  /// @dev EIP-712 createAction typehash.
  bytes32 internal constant CREATE_ACTION_TYPEHASH = keccak256(
    "CreateAction(address tokenHolder,uint8 role,address strategy,address target,uint256 value,bytes data,string description,uint256 nonce)"
  );

  /// @dev EIP-712 cancelAction typehash.
  bytes32 internal constant CANCEL_ACTION_TYPEHASH = keccak256(
    "CancelAction(address tokenHolder,ActionInfo actionInfo,uint256 nonce)ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @notice EIP-712 castVote typehash.
  bytes32 internal constant CAST_VOTE_TYPEHASH = keccak256(
    "CastVote(address tokenHolder,uint8 role,ActionInfo actionInfo,uint8 support,string reason,uint256 nonce)ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @notice EIP-712 castVeto typehash.
  bytes32 internal constant CAST_VETO_TYPEHASH = keccak256(
    "CastVeto(address tokenHolder,uint8 role,ActionInfo actionInfo,uint8 support,string reason,uint256 nonce)ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  /// @notice EIP-712 actionInfo typehash.
  bytes32 internal constant ACTION_INFO_TYPEHASH = keccak256(
    "ActionInfo(uint256 id,address creator,uint8 creatorRole,address strategy,address target,uint256 value,bytes data)"
  );

  bytes32 internal DOMAIN_SEPARATOR;

  /// @notice Sets the EIP-712 domain separator.
  function setDomainHash(EIP712Domain memory eip712Domain) internal {
    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN_TYPEHASH,
        keccak256(bytes(eip712Domain.name)),
        keccak256(bytes(eip712Domain.version)),
        eip712Domain.chainId,
        eip712Domain.verifyingContract
      )
    );
  }

  /// @notice Returns the hash of CreateAction.
  function getCreateActionHash(CreateAction memory createAction) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CREATE_ACTION_TYPEHASH,
        createAction.tokenHolder,
        createAction.role,
        createAction.strategy,
        createAction.target,
        createAction.value,
        keccak256(createAction.data),
        keccak256(bytes(createAction.description)),
        createAction.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CreateAction domain, which can be used to
  /// recover the signer.
  function getCreateActionTypedDataHash(CreateAction memory createAction) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCreateActionHash(createAction)));
  }

  /// @notice Returns the hash of CancelActionBySig.
  function getCancelActionHash(CancelAction memory cancelAction) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CANCEL_ACTION_TYPEHASH, cancelAction.tokenHolder, getActionInfoHash(cancelAction.actionInfo), cancelAction.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CancelAction domain, which can be used to
  /// recover the signer.
  function getCancelActionTypedDataHash(CancelAction memory cancelAction) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCancelActionHash(cancelAction)));
  }

  /// @notice Returns the hash of CastVote.
  function getCastVoteHash(CastVote memory castVote) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_VOTE_TYPEHASH,
        castVote.tokenHolder,
        castVote.role,
        getActionInfoHash(castVote.actionInfo),
        castVote.support,
        keccak256(bytes(castVote.reason)),
        castVote.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastVote domain, which can be used to
  /// recover the signer.
  function getCastVoteTypedDataHash(CastVote memory castVote) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastVoteHash(castVote)));
  }

  /// @notice Returns the hash of CastDisapprovalBySig.
  function getCastVetoHash(CastVeto memory castVeto) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        CAST_VETO_TYPEHASH,
        castVeto.tokenHolder,
        castVeto.role,
        getActionInfoHash(castVeto.actionInfo),
        castVeto.support,
        keccak256(bytes(castVeto.reason)),
        castVeto.nonce
      )
    );
  }

  /// @notice Returns the hash of the fully encoded EIP-712 message for the CastVeto domain, which can be used to
  /// recover the signer.
  function getCastVetoTypedDataHash(CastVeto memory castVeto) internal view returns (bytes32) {
    return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getCastVetoHash(castVeto)));
  }

  /// @notice Returns the hash of ActionInfo.
  function getActionInfoHash(ActionInfo memory actionInfo) internal pure returns (bytes32) {
    return keccak256(
      abi.encode(
        ACTION_INFO_TYPEHASH,
        actionInfo.id,
        actionInfo.creator,
        actionInfo.creatorRole,
        address(actionInfo.strategy),
        actionInfo.target,
        actionInfo.value,
        keccak256(actionInfo.data)
      )
    );
  }
}
