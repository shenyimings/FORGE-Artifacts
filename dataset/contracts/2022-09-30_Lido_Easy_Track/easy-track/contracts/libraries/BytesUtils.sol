// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @author psirex
/// @notice Contains methods to extract primitive types from bytes
library BytesUtils {
    function bytes24At(bytes memory data, uint256 location) internal pure returns (bytes24 result) {
        uint256 word = uint256At(data, location);
        assembly {
            result := word
        }
    }

    function addressAt(bytes memory data, uint256 location) internal pure returns (address result) {
        uint256 word = uint256At(data, location);
        assembly {
            result := shr(
                96,
                and(word, 0xffffffffffffffffffffffffffffffffffffffff000000000000000000000000)
            )
        }
    }

    function uint32At(bytes memory _data, uint256 _location) internal pure returns (uint32 result) {
        uint256 word = uint256At(_data, _location);

        assembly {
            result := shr(
                224,
                and(word, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            )
        }
    }

    function uint256At(bytes memory data, uint256 location) internal pure returns (uint256 result) {
        assembly {
            result := mload(add(data, add(0x20, location)))
        }
    }
}
