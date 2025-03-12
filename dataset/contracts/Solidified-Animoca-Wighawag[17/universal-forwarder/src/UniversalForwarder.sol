// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../_lib/openzeppelin/contracts/utils/Address.sol";
import "../_lib/openzeppelin/contracts/cryptography/ECDSA.sol";
import "./solc_0.7/ERC2771/IERC2771.sol";
import "./solc_0.7/ERC2771/UsingAppendedCallData.sol";

interface ERC1271 {
    function isValidSignature(bytes calldata data, bytes calldata signature) external view returns (bytes4 magicValue);
}

interface ERC1654 {
    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4 magicValue);
}

/// @notice Universal Meta Transaction Forwarder
/// It does not perform any extra logic apart from checking if the caller (metatx forwarder) has been approved via signature.
/// Note that forwarder approval are forever. This is to remove the need to read storage. Signature need to be given each time.
/// The overhead (on top of the specific metatx forwarder) is thus just an extra contract load and call + signature check.
contract UniversalForwarder is UsingAppendedCallData, IERC2771 {
    using Address for address;
    using ECDSA for bytes32;

    enum SignatureType {DIRECT, EIP1654, EIP1271}
    bytes4 internal constant ERC1271_MAGICVALUE = 0x20c13b0b;
    bytes4 internal constant ERC1654_MAGICVALUE = 0x1626ba7e;

    bytes32 internal constant EIP712DOMAIN_NAME = keccak256("UniversalForwarder");
    bytes32 internal constant APPROVAL_TYPEHASH = keccak256("ApproveForwarderForever(address forwarder)");

    uint256 private immutable _deploymentChainId;
    bytes32 private immutable _deploymentDomainSeparator;

    constructor() {
        uint256 chainId;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }
        _deploymentChainId = chainId;
        _deploymentDomainSeparator = _calculateDomainSeparator(chainId);
    }

    /// @notice The UniversalForwarder supports every EIP-2771 compliant forwarder.
    function isTrustedForwarder(address) external pure override returns (bool) {
        return true;
    }

    /// @notice Forward the meta transaction by first checking signature if forwarder is approved : no storage involved, approving is forever.
    /// @param signature signature by signer for approving forwarder.
    /// @param target destination of the call (that will receive the meta transaction).
    /// @param data the content of the call (the signer address will be appended to it).
    function forward(
        bytes calldata signature,
        SignatureType signatureType,
        address target,
        bytes calldata data
    ) external payable {
        address signer = _lastAppendedDataAsSender();
        _requireValidSignature(signer, msg.sender, signature, signatureType);
        target.functionCallWithValue(abi.encodePacked(data, signer), msg.value);
    }

    /// @dev Return the DOMAIN_SEPARATOR.
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _DOMAIN_SEPARATOR();
    }

    // -------------------------------------------------------- INTERNAL --------------------------------------------------------------------

    /// @dev Return the DOMAIN_SEPARATOR.
    function _DOMAIN_SEPARATOR() internal view returns (bytes32) {
        uint256 chainId;
        //solhint-disable-next-line no-inline-assembly
        assembly {
            chainId := chainid()
        }

        // in case a fork happen, to support the chain that had to change its chainId,, we compue the domain operator
        return chainId == _deploymentChainId ? _deploymentDomainSeparator : _calculateDomainSeparator(chainId);
    }

    /// @dev Calculate the DOMAIN_SEPARATOR.
    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                    EIP712DOMAIN_NAME,
                    chainId,
                    address(this)
                )
            );
    }

    function _encodeMessage(address forwarder) internal view returns (bytes memory) {
        return abi.encodePacked("\x19\x01", _DOMAIN_SEPARATOR(), keccak256(abi.encode(APPROVAL_TYPEHASH, forwarder)));
    }

    function _requireValidSignature(
        address signer,
        address forwarder,
        bytes memory signature,
        SignatureType signatureType
    ) internal view {
        bytes memory dataToHash = _encodeMessage(forwarder);
        if (signatureType == SignatureType.EIP1271) {
            require(
                ERC1271(signer).isValidSignature(dataToHash, signature) == ERC1271_MAGICVALUE,
                "SIGNATURE_1271_INVALID"
            );
        } else if (signatureType == SignatureType.EIP1654) {
            require(
                ERC1654(signer).isValidSignature(keccak256(dataToHash), signature) == ERC1654_MAGICVALUE,
                "SIGNATURE_1654_INVALID"
            );
        } else {
            address actualSigner = keccak256(dataToHash).recover(signature);
            require(signer == actualSigner, "SIGNATURE_WRONG_SIGNER");
        }
    }
}
