// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {IERC1271} from "./../../cryptography/interfaces/IERC1271.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ERC1271Mock is IERC1271 {
    using ECDSA for bytes32;

    address internal immutable _OWNER;

    constructor(address owner) {
        _OWNER = owner;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4 magicValue) {
        address signer = hash.recover(signature);
        if (signer == _OWNER) {
            return 0x1626ba7e;
        } else {
            return 0xffffffff;
        }
    }
}
