// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Bytes32} from "./../../utils/libraries/Bytes32.sol";

contract Bytes32Mock {
    function toBase32String(bytes32 value) external pure returns (string memory) {
        return Bytes32.toBase32String(value);
    }

    function toASCIIString(bytes32 value) external pure returns (string memory) {
        return Bytes32.toASCIIString(value);
    }
}
