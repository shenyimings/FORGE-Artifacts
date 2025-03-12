// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "../libraries/BytesUtils.sol";

/// @author psirex
/// @notice Helper contract to test internal methods of BytesUtils library
library BytesUtilsWrapper {
    function bytes24At(bytes memory data, uint256 location) external pure returns (bytes24 result) {
        return BytesUtils.bytes24At(data, location);
    }

    function addressAt(bytes memory data, uint256 location) external pure returns (address result) {
        return BytesUtils.addressAt(data, location);
    }

    function uint32At(bytes memory _data, uint256 _location) external pure returns (uint32 result) {
        return BytesUtils.uint32At(_data, _location);
    }

    function uint256At(bytes memory data, uint256 location) external pure returns (uint256 result) {
        return BytesUtils.uint256At(data, location);
    }
}
