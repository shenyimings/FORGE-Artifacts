// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.22;

/// @notice Contract interface for paying gas fees for users and forwarding meta transactions to OrderProcessor contracts.
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/forwarder/IForwarder.sol)
interface IForwarder {
    struct ForwardRequest {
        address user; // The address of the user initiating the meta-transaction.
        address to; // The address of the target contract (e.g., OrderProcessor)
            // to which the meta-transaction should be forwarded.
        address paymentToken; // token use to pay transaction
        bytes data; // Encoded function call that the user wants to execute
            // through the meta-transaction.
        uint64 deadline; // The time by which the meta-transaction must be mined.
        uint256 nonce; // A nonce to prevent replay attacks. It must be unique
            // for each meta-transaction made by the user.
        bytes signature; // ECDSA signature of the user authorizing the meta-transaction.
    }

    /// @notice The fee rate in basis points (1 basis point = 0.01%) for paying gas fees in tokens.
    function feeBps() external view returns (uint16);

    /// @notice Gas cost estimate added to cover oder cancellations.
    function cancellationGasCost() external view returns (uint256);

    /// @notice The mapping of relayer addresses authorize to send meta transactions.
    function isRelayer(address relayer) external view returns (bool);

    /// @notice The mapping of order IDs to signers used for order cancellation protection.
    function orderSigner(bytes32 orderId) external view returns (address);

    /// @notice EIP-712 compliant forward request hash function.
    function forwardRequestHash(ForwardRequest calldata metaTx) external pure returns (bytes32);

    /**
     * @notice Forwards a meta transaction to an OrderProcessor contract.
     * @dev Validates the meta transaction signature, then forwards the call to the target OrderProcessor.
     * The relayer's address is used for EIP-712 compliant signature verification.
     * This function should only be called by the authorized relayer.
     * @param metaTx The meta transaction containing the user address, target contract, encoded function call data,
     * deadline, nonce, payment token oracle price, and the signature components (v, r, s).
     * @return The return data of the forwarded function call.
     */
    function forwardFunctionCall(ForwardRequest calldata metaTx) external returns (bytes memory);
}
