// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract SigMetaUtils {
    bytes32 internal immutable DOMAIN_SEPARATOR;
    bytes private constant FORWARDREQUEST_TYPE = abi.encodePacked(
        "ForwardRequest(address user,address to,address paymentToken,bytes data,uint64 deadline,uint256 nonce)"
    );
    bytes32 private constant FORWARDREQUEST_TYPEHASH = keccak256(FORWARDREQUEST_TYPE);

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    struct ForwardRequest {
        address user;
        address to;
        address paymentToken;
        bytes data;
        uint64 deadline;
        uint256 nonce;
    }

    function _hashForwardRequest(ForwardRequest calldata metaTx) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                FORWARDREQUEST_TYPEHASH,
                metaTx.user,
                metaTx.to,
                metaTx.paymentToken,
                keccak256(metaTx.data),
                metaTx.deadline,
                metaTx.nonce
            )
        );
    }

    function getHashToSign(ForwardRequest calldata metaTx) public view returns (bytes32) {
        // This uses EIP712's _hashTypedDataV4 which conforms to the standard
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, _hashForwardRequest(metaTx)));
    }
}
