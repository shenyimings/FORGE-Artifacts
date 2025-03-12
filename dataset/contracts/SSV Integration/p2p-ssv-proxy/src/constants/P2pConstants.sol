// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/// @dev Collateral size of 1 validator
uint256 constant COLLATERAL = 32 ether;

/// @dev Maximum number of SSV operator IDs per SSV operator owner address supported simultaniously by P2pSsvProxyFactory
uint256 constant MAX_ALLOWED_SSV_OPERATOR_IDS = 8;
