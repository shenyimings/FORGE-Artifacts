// SPDX-License-Identifier: ISC
pragma solidity ^0.8.19;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================= FraxGuard ================================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author(s)
// Jon Walch: https://github.com/jonwalch

// Reviewers
// Drake Evans: https://github.com/DrakeEvans
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian

// ====================================================================

import { IERC165 } from "@gnosis.pm/contracts/interfaces/IERC165.sol";
import { Guard } from "@gnosis.pm/contracts/base/GuardManager.sol";
import { Enum, ISafe } from "./interfaces/ISafe.sol";

/// @title FraxGuard
/// @author Jon Walch (Frax Finance) https://github.com/jonwalch
/// @notice  A Gnosis Safe Guard that restricts Safe transaction execution to Safe owners and requires approval from FraxGovernorOmega
contract FraxGuard is IERC165, Guard {
    /// @notice The address of the FraxGovernorOmega contract
    address public immutable FRAX_GOVERNOR_OMEGA_ADDRESS;

    /// @notice The ```constructor``` function is called on deployment
    /// @param fraxGovernorOmega The address of the FraxGovernorOmega contract
    constructor(address fraxGovernorOmega) {
        FRAX_GOVERNOR_OMEGA_ADDRESS = fraxGovernorOmega;
    }

    /// @notice The ```checkTransaction``` function is a "callback" from within GnosisSafe::execTransaction() that runs before execution
    /// @param to Destination address of Safe transaction.
    /// @param value Ether value of Safe transaction.
    /// @param data Data payload of Safe transaction.
    /// @param operation Operation type of Safe transaction.
    /// @param safeTxGas Gas that should be used for the Safe transaction.
    /// @param baseGas Gas costs that are independent of the transaction execution(e.g. base transaction fee, signature check, payment of the refund)
    /// @param gasPrice Gas price that should be used for the payment calculation.
    /// @param gasToken Token address (or 0 if ETH) that is used for the payment.
    /// @param refundReceiver Address of receiver of gas payment (or 0 if tx.origin).
    /// @param msgSender Address of caller of GnosisSafe::execTransaction()
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory, // signatures Packed signature data ({bytes32 r}{bytes32 s}{uint8 v})
        address msgSender
    ) external {
        ISafe safe = ISafe(msg.sender);
        bytes32 txHash = safe.getTransactionHash({
            to: to,
            value: value,
            data: data,
            operation: operation,
            safeTxGas: safeTxGas,
            baseGas: baseGas,
            gasPrice: gasPrice,
            gasToken: gasToken,
            refundReceiver: refundReceiver,
            _nonce: safe.nonce() - 1 // nonce gets incremented before this function is called
        });
        if (
            !safe.isOwner(msgSender) ||
            safe.approvedHashes({ signer: FRAX_GOVERNOR_OMEGA_ADDRESS, txHash: txHash }) != 1
        ) {
            revert Unauthorized();
        }
    }

    /// @notice The ```checkAfterExecution``` function is a "callback" from within GnosisSafe::execTransaction() that runs after execution
    function checkAfterExecution(bytes32, /* txHash */ bool /* success */) external {}

    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return
            interfaceId == type(Guard).interfaceId || // 0xe6d7a83a
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }

    error Unauthorized();
}
