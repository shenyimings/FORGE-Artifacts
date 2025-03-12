// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import '@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol';
import '@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol';
import '../OrderStructs.sol';

/**
 * @notice Verifies the signature of orders and hashes the order data in the way that
 * later the signer can be recovered from the signature.
 */
library OrderSignatureVerifierLib {
  error OrderSignatureVerifier__InvalidOrderHash();

  /**
   * @notice Returns the chain id of the current network
   * @return chainId chain id of the current network
   */
  function _getChainId() internal view returns (uint256 chainId) {
    assembly {
      chainId := chainid()
    }
    return chainId;
  }

  /**
   * @notice Hashes the order data in the way that later the signer can be recovered from the signature.
   * @param order the order data
   */
  function hashPublicOrder(PublicOrder memory order) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          _getChainId(),
          order.deadline,
          order.makerSellToken,
          order.makerSellTokenAmount,
          order.makerBuyToken,
          order.makerBuyTokenAmount,
          order.creationTimestamp
        )
      );
  }

  /**
   * @notice Hashes the order data in the way that later the signer can be recovered from the signature.
   * @param order the order data
   */
  function hashPrivateOrder(PrivateOrder memory order) internal view returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          _getChainId(),
          order.maker,
          order.deadline,
          order.makerSellToken,
          order.makerSellTokenAmount,
          order.makerBuyToken,
          order.makerBuyTokenAmount,
          order.recipient,
          order.creationTimestamp
        )
      );
  }

  /**
   * @notice Verifies if the signature matches private order data and a hash of the order data.
   * @param order order data
   * @param orderHash hash of the order data
   * @param signature signature of the order data
   */
  function verifyPrivateOrder(
    PrivateOrder memory order,
    bytes32 orderHash,
    bytes memory signature
  ) internal view returns (bool) {
    if (hashPrivateOrder(order) != orderHash) {
      revert OrderSignatureVerifier__InvalidOrderHash();
    }

    bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(orderHash);

    return
      SignatureChecker.isValidSignatureNow(order.maker, ethSignedMessageHash, signature);
  }
}
