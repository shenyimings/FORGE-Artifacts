// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../interfaces/ssv/ISSVClusters.sol";

/// @dev 256 bit struct
/// @member basisPoints basis points (percent * 100) of EL rewards that should go to the recipient
/// @member recipient address of the recipient
struct FeeRecipient {
    uint96 basisPoints;
    address payable recipient;
}

/// @member pubkey The public key of the new validator
/// @member sharesData Encrypted shares related to the new validator
struct SsvValidator {
    bytes pubkey;
    bytes sharesData;
}

/// @member signatures BLS12-381 signatures
/// @member depositDataRoots SHA-256 hashes of the SSZ-encoded DepositData objects
struct DepositData {
    bytes[] signatures;
    bytes32[] depositDataRoots;
}

/// @dev Data from https://github.com/bloxapp/ssv-network/blob/8c945e82cc063eb8e40c467d314a470121821157/contracts/interfaces/ISSVNetworkCore.sol#L20
/// @member owner SSV operator owner
/// @member id SSV operator ID
/// @member snapshot SSV operator snapshot (should be retrieved from SSVNetwork storage)
/// @member fee SSV operator fee
struct SsvOperator {
    address owner;
    uint64 id;
    bytes32 snapshot;
    uint256 fee;
}

/// @member ssvOperators SSV operators for the cluster
/// @member ssvValidators new SSV validators to be registered in the cluster
/// @member cluster SSV cluster
/// @member tokenAmount amount of ERC-20 SSV tokens for validator registration
/// @member ssvSlot0 Slot # (uint256(keccak256("ssv.network.storage.protocol")) - 1) from SSVNetwork
struct SsvPayload {
    SsvOperator[] ssvOperators;
    SsvValidator[] ssvValidators;
    ISSVClusters.Cluster cluster;
    uint256 tokenAmount;
    bytes32 ssvSlot0;
}
