// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

/// @author psirex
/// @notice A helper contract contains logic to validate that only a trusted caller has access to certain methods.
/// @dev Trusted caller set once on deployment and can't be changed.
contract TrustedCaller {
    string private constant ERROR_TRUSTED_CALLER_IS_ZERO_ADDRESS = "TRUSTED_CALLER_IS_ZERO_ADDRESS";
    string private constant ERROR_CALLER_IS_FORBIDDEN = "CALLER_IS_FORBIDDEN";

    address public immutable trustedCaller;

    constructor(address _trustedCaller) {
        require(_trustedCaller != address(0), ERROR_TRUSTED_CALLER_IS_ZERO_ADDRESS);
        trustedCaller = _trustedCaller;
    }

    modifier onlyTrustedCaller(address _caller) {
        require(_caller == trustedCaller, ERROR_CALLER_IS_FORBIDDEN);
        _;
    }
}
