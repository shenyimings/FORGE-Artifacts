//SPDX-License-Identifier: WTFPL

pragma solidity 0.8.12;

/// @title Utility signature contract
/// @author Noah Jelich
/// @notice Used by VotingEngine and Signature to validate signatures provided by our owner wallet
/// @dev The unused verify and getMessageHash function will be removed when compiling contracts via optimizer dead code
contract Signature {
  function getMessageHash(
    address to,
    uint256 amount,
    uint256 nonce
  ) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(to, amount, nonce));
  }

  function getMessageHashNFT(address to) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(to));
  }

  function getEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32) {
    // Signature is produced by signing a keccak256 hash with the following format:
    // "\x19Ethereum Signed Message\n" + len(msg) + msg

    return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
  }

  function verify(
    address signer,
    address to,
    uint256 amount,
    uint256 nonce,
    bytes calldata signature
  ) internal pure returns (bool) {
    bytes32 messageHash = getMessageHash(to, amount, nonce);
    bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

    return recoverSigner(ethSignedMessageHash, signature) == signer;
  }

  function verifyNFT(
    address signer,
    address to,
    bytes calldata signature
  ) internal pure returns (bool) {
    bytes32 messageHash = getMessageHashNFT(to);
    bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

    return recoverSigner(ethSignedMessageHash, signature) == signer;
  }

  function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
    (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

    return ecrecover(ethSignedMessageHash, v, r, s);
  }

  function splitSignature(bytes memory signature)
    internal
    pure
    returns (
      bytes32 r,
      bytes32 s,
      uint8 v
    )
  {
    require(signature.length == 65, "Invalid signature length");

    assembly {
      /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

      // first 32 bytes, after the length prefix
      r := mload(add(signature, 32))
      // second 32 bytes
      s := mload(add(signature, 64))
      // final byte (first byte of the next 32 bytes)
      v := byte(0, mload(add(signature, 96)))
    }

    // implicitly return (r, s, v)
  }
}
