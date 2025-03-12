// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (metatx/ERC2771Forwarder.sol)

pragma solidity ^0.8.8;

import {ERC2771Context} from "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "openzeppelin-contracts/contracts/utils/Nonces.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract DOGAMI_Relayer is EIP712, Nonces, Ownable {
    using ECDSA for bytes32;

    mapping(address => bool) private _whitelistedAddresses;

    event AddressAddedToWhitelist(address indexed account);
    event AddressRemovedFromWhitelist(address indexed account);

    struct ForwardRequestData {
        address from;
        address to;
        uint256 value;
        uint256 gas;
        uint48 deadline;
        bytes data;
        bytes signature;
    }

    function addToWhitelist(address account) public onlyOwner {
        require(account != address(0), "Cannot add zero address to whitelist.");
        require(!_whitelistedAddresses[account], "Address already whitelisted.");

        _whitelistedAddresses[account] = true;
        emit AddressAddedToWhitelist(account);
    }

    function removeFromWhitelist(address account) public onlyOwner {
        require(account != address(0), "Cannot remove zero address from whitelist.");
        require(_whitelistedAddresses[account], "Address not in whitelist.");

        _whitelistedAddresses[account] = false;
        emit AddressRemovedFromWhitelist(account);
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelistedAddresses[account];
    }


    bytes32 internal constant _FORWARD_REQUEST_TYPEHASH =
    keccak256(
        "ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint48 deadline,bytes data)"
    );

    event ExecutedForwardRequest(address indexed signer, uint256 nonce, bool success);

/**
 * @dev The request `from` doesn't match with the recovered `signer`.
     */
    error ERC2771ForwarderInvalidSigner(address signer, address from);

/**
 * @dev The `requestedValue` doesn't match with the available `msgValue`.
     */
    error ERC2771ForwarderMismatchedValue(uint256 requestedValue, uint256 msgValue);

/**
 * @dev The request `deadline` has expired.
     */
    error ERC2771ForwarderExpiredRequest(uint48 deadline);

/**
 * @dev The request target doesn't trust the `forwarder`.
     */
    error ERC2771UntrustfulTarget(address target, address forwarder);

/**
 * @dev See {EIP712-constructor}.
     */
    constructor(string memory name, address _owner) EIP712(name, "1")  Ownable(_owner) {}

    function verify(ForwardRequestData calldata request) public view virtual returns (bool) {
        (bool isTrustedForwarder, bool active, bool signerMatch,) = _validate(request);
        return isTrustedForwarder && active && signerMatch;
    }

    function execute(ForwardRequestData calldata request) public payable virtual {
        require(isWhitelisted(msg.sender), "Caller is not whitelisted.");

        if (msg.value != request.value) {
            revert ERC2771ForwarderMismatchedValue(request.value, msg.value);
        }

        if (!_execute(request, true)) {
            revert Address.FailedInnerCall();
        }
    }

    function executeBatch(
        ForwardRequestData[] calldata requests,
        address payable refundReceiver
    ) public payable virtual {
        bool atomic = refundReceiver == address(0);

        uint256 requestsValue;
        uint256 refundValue;

        for (uint256 i; i < requests.length; ++i) {
            requestsValue += requests[i].value;
            bool success = _execute(requests[i], atomic);
            if (!success) {
                refundValue += requests[i].value;
            }
        }

        if (requestsValue != msg.value) {
            revert ERC2771ForwarderMismatchedValue(requestsValue, msg.value);
        }


        if (refundValue != 0) {

            Address.sendValue(refundReceiver, refundValue);
        }
    }


    function _validate(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool isTrustedForwarder, bool active, bool signerMatch, address signer) {
        (bool isValid, address recovered) = _recoverForwardRequestSigner(request);

        return (
            _isTrustedByTarget(request.to),
            request.deadline >= block.timestamp,
            isValid && recovered == request.from,
            recovered
        );
    }

/**
 * @dev Returns a tuple with the recovered the signer of an EIP712 forward request message hash
     * and a boolean indicating if the signature is valid.
     *
     * NOTE: The signature is considered valid if {ECDSA-tryRecover} indicates no recover error for it.
     */
    function _recoverForwardRequestSigner(
        ForwardRequestData calldata request
    ) internal view virtual returns (bool, address) {
        (address recovered, ECDSA.RecoverError err,) = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    nonces(request.from),
                    request.deadline,
                    keccak256(request.data)
                )
            )
        ).tryRecover(request.signature);

        return (err == ECDSA.RecoverError.NoError, recovered);
    }


    function _execute(
        ForwardRequestData calldata request,
        bool requireValidRequest
    ) internal virtual returns (bool success) {
        (bool isTrustedForwarder, bool active, bool signerMatch, address signer) = _validate(request);

// Need to explicitly specify if a revert is required since non-reverting is default for
// batches and reversion is opt-in since it could be useful in some scenarios
        if (requireValidRequest) {
            if (!isTrustedForwarder) {
                revert ERC2771UntrustfulTarget(request.to, address(this));
            }

            if (!active) {
                revert ERC2771ForwarderExpiredRequest(request.deadline);
            }

            if (!signerMatch) {
                revert ERC2771ForwarderInvalidSigner(signer, request.from);
            }
        }

// Ignore an invalid request because requireValidRequest = false
        if (isTrustedForwarder && signerMatch && active) {
// Nonce should be used before the call to prevent reusing by reentrancy
            uint256 currentNonce = _useNonce(signer);

            uint256 reqGas = request.gas;
            address to = request.to;
            uint256 value = request.value;
            bytes memory data = abi.encodePacked(request.data, request.from);

            uint256 gasLeft;

            assembly {
                success := call(reqGas, to, value, add(data, 0x20), mload(data), 0, 0)
                gasLeft := gas()
            }

            _checkForwardedGas(gasLeft, request);

            emit ExecutedForwardRequest(signer, currentNonce, success);
        }
    }

/**
 * @dev Returns whether the target trusts this forwarder.
     *
     * This function performs a static call to the target contract calling the
     * {ERC2771Context-isTrustedForwarder} function.
     */
    function _isTrustedByTarget(address target) private view returns (bool) {
        bytes memory encodedParams = abi.encodeCall(ERC2771Context.isTrustedForwarder, (address(this)));

        bool success;
        uint256 returnSize;
        uint256 returnValue;
/// @solidity memory-safe-assembly
        assembly {
// Perform the staticcal and save the result in the scratch space.
// | Location  | Content  | Content (Hex)                                                      |
// |-----------|----------|--------------------------------------------------------------------|
// |           |          |                                                           result â†“ |
// | 0x00:0x1F | selector | 0x0000000000000000000000000000000000000000000000000000000000000001 |
            success := staticcall(gas(), target, add(encodedParams, 0x20), mload(encodedParams), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }


    function _checkForwardedGas(uint256 gasLeft, ForwardRequestData calldata request) private pure {

        if (gasLeft < request.gas / 63) {
// We explicitly trigger invalid opcode to consume all gas and bubble-up the effects, since
// neither revert or assert consume all gas since Solidity 0.8.20
// https://docs.soliditylang.org/en/v0.8.20/control-structures.html#panic-via-assert-and-error-via-require
/// @solidity memory-safe-assembly
            assembly {
                invalid()
            }
        }
    }
}