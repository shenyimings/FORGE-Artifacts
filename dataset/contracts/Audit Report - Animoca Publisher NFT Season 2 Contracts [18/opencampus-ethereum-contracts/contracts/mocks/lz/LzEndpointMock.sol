// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ILayerZeroReceiver} from "@layerzerolabs/solidity-examples/contracts/interfaces/ILayerZeroReceiver.sol";

/// @title LzEndpointMock
contract LzEndpointMock {
    event LzSent(
        uint16 dstChainId,
        address srcAddress,
        address dstAddress,
        bytes payload,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes adapterParams
    );

    event ForceResume(uint16 srcChainId, bytes srcAddress);
    event PayloadRetry(uint16 srcChainId, bytes srcAddress, bytes payload);

    /// @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    /// @param dstChainId - the destination chain identifier
    /// @param destination_ - the address on destination chain (in bytes). address length/format may vary by chains
    /// @param payload_ - a custom bytes payload to send to the destination contract
    /// @param refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    /// @param zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
    /// @param adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
    function send(
        uint16 dstChainId,
        bytes memory destination_,
        bytes calldata payload_,
        address payable refundAddress,
        address zroPaymentAddress,
        bytes calldata adapterParams
    ) external payable {
        address dstAddress = address(bytes20(destination_));
        address srcAddress;
        assembly {
            srcAddress := mload(add(destination_, 40))
        }

        emit LzSent(dstChainId, srcAddress, dstAddress, payload_, refundAddress, zroPaymentAddress, adapterParams);
    }

    function callLzReceive(uint16 srcChainId, address srcAddress, address dstAddress, bytes memory payload) external {
        bytes memory destination = abi.encodePacked(srcAddress, dstAddress); // Note: the encoding is reversed compared to what was received via send
        ILayerZeroReceiver(dstAddress).lzReceive(srcChainId, destination, 0, payload);
    }

    function forceResumeReceive(uint16 srcChainId, bytes calldata srcAddress) external {
        emit ForceResume(srcChainId, srcAddress);
    }

    function retryPayload(uint16 srcChainId, bytes calldata srcAddress, bytes calldata payload) external {
        emit PayloadRetry(srcChainId, srcAddress, payload);
    }

    function estimateFees(uint16, address, bytes calldata, bool, bytes calldata) external pure returns (uint256, uint256) {
        return (100, 100);
    }
}
