// SPDX-License-Identifier: Apache
/*
  Copyright 2020 Swap Holdings Ltd.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

pragma solidity ^0.7.2;
pragma experimental ABIEncoderV2;

/**
 * @title Types: Library of Swap Protocol Types and Hashes
 */
library Types {
    struct Order {
        uint256 nonce; // Unique per order and should be sequential
        uint256 expiry; // Expiry in seconds since 1 January 1970
        Party signer; // Party to the trade that sets terms
        Party sender; // Party to the trade that accepts terms
        Party affiliate; // Party compensated for facilitating (optional)
        Signature signature; // Signature of the order
    }

    struct Party {
        bytes4 kind; // Interface ID of the token
        address wallet; // Wallet address of the party
        address token; // Contract address of the token
        uint256 amount; // Amount for ERC-20 or ERC-1155
        uint256 id; // ID for ERC-721 or ERC-1155
    }

    struct Signature {
        address signatory; // Address of the wallet used to sign
        address validator; // Address of the intended swap contract
        bytes1 version; // EIP-191 signature version
        uint8 v; // `v` value of an ECDSA signature
        bytes32 r; // `r` value of an ECDSA signature
        bytes32 s; // `s` value of an ECDSA signature
    }
}

interface ISwap {
    event Swap(
        uint256 indexed nonce,
        uint256 timestamp,
        address indexed signerWallet,
        uint256 signerAmount,
        uint256 signerId,
        address signerToken,
        address indexed senderWallet,
        uint256 senderAmount,
        uint256 senderId,
        address senderToken,
        address affiliateWallet,
        uint256 affiliateAmount,
        uint256 affiliateId,
        address affiliateToken
    );

    event Cancel(uint256 indexed nonce, address indexed signerWallet);

    event CancelUpTo(uint256 indexed nonce, address indexed signerWallet);

    event AuthorizeSender(
        address indexed authorizerAddress,
        address indexed authorizedSender
    );

    event AuthorizeSigner(
        address indexed authorizerAddress,
        address indexed authorizedSigner
    );

    event RevokeSender(
        address indexed authorizerAddress,
        address indexed revokedSender
    );

    event RevokeSigner(
        address indexed authorizerAddress,
        address indexed revokedSigner
    );

    /**
     * @notice Atomic Token Swap
     * @param order Types.Order
     */
    function swap(Types.Order calldata order) external;

    /**
     * @notice Cancel one or more open orders by nonce
     * @param nonces uint256[]
     */
    function cancel(uint256[] calldata nonces) external;

    /**
     * @notice Cancels all orders below a nonce value
     * @dev These orders can be made active by reducing the minimum nonce
     * @param minimumNonce uint256
     */
    function cancelUpTo(uint256 minimumNonce) external;

    /**
     * @notice Authorize a delegated sender
     * @param authorizedSender address
     */
    function authorizeSender(address authorizedSender) external;

    /**
     * @notice Authorize a delegated signer
     * @param authorizedSigner address
     */
    function authorizeSigner(address authorizedSigner) external;

    /**
     * @notice Revoke an authorization
     * @param authorizedSender address
     */
    function revokeSender(address authorizedSender) external;

    /**
     * @notice Revoke an authorization
     * @param authorizedSigner address
     */
    function revokeSigner(address authorizedSigner) external;

    function senderAuthorizations(address, address)
        external
        view
        returns (bool);

    function signerAuthorizations(address, address)
        external
        view
        returns (bool);

    function signerNonceStatus(address, uint256) external view returns (bytes1);

    function signerMinimumNonce(address) external view returns (uint256);

    function registry() external view returns (address);
}
