// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/IControlL2MerkleDistributor.sol";
import {ICrossDomainMessenger} from "@eth-optimism/contracts/libraries/bridge/ICrossDomainMessenger.sol";

/// @title Kwenta ControlL2MerkleDistributor
/// @author JaredBorders
/// @notice This L1 deployed contract is responsible for communicating with the
/// MerkleDistributor deployed on L2 (Optimism Mainnet)
contract ControlL2MerkleDistributor is IControlL2MerkleDistributor {
    /// @notice communication between L1 and L2 is enabled by two special
    /// smart contracts called the "messengers"
    /// and below is the address for the messenger on L1
    address internal immutable crossDomainMessengerAddr;

    /// @notice MerkleDistributor deployed on L2
    address internal immutable merkleDistributorL2Address;

    /// @notice set addresses for deployed MerkleDistributor on L2 and
    /// OE cross domain messenger address on L1
    /// @param _crossDomainMessengerAddr: messenger on L1 enabling communication to L2
    /// @param _merkleDistributorL2Address: Kwenta MerkleDistributor on L2
    constructor(
        address _crossDomainMessengerAddr,
        address _merkleDistributorL2Address
    ) {
        crossDomainMessengerAddr = _crossDomainMessengerAddr;
        merkleDistributorL2Address = _merkleDistributorL2Address;
    }

    /// @notice claim $KWENTA on L2 from an L1 address
    /// @dev destAccount will be the address used to create new escrow entry
    /// @dev the function caller (i.e. msg.sender) will be provided as a parameter
    /// to MerkleDistributor.claimToAddress() on L2. Only valid callers will
    /// be able to claim
    /// @param index: used for merkle tree managment and verification
    /// @param destAccount: address used for escrow entry
    /// @param amount: $KWENTA amount to be escrowed
    /// @param merkleProof: off-chain generated proof of merkle tree inclusion
    function claimToAddress(
        uint256 index,
        address destAccount,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override {
        bytes memory message;
        message = abi.encodeWithSignature(
            "claimToAddress(uint256,address,address,uint256,bytes32[])",
            index,
            /// @notice account to be verified in merkle tree
            msg.sender,
            /// @notice address used for escrow entry
            /// @dev does not necessarily have to be different from msg.sender
            destAccount,
            amount,
            merkleProof
        );

        /// @notice send message to CrossDomainMessenger which will communicate message to L2
        ICrossDomainMessenger(crossDomainMessengerAddr).sendMessage(
            merkleDistributorL2Address,
            message,
            1000000 // within the free gas limit amount
        );
    }
}
