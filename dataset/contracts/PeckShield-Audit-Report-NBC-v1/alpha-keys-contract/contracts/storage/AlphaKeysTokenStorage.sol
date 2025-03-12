// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {TokenTypes} from "../libraries/TokenTypes.sol";

abstract contract AlphaKeysTokenStorage {
    address internal _factory;
    address internal _reserve0;
    address internal _player;
    uint256 internal _createdTimestamp;
    // btcMigrated
    bool internal _btcMigrated;
    // user -> duation -> array locked data
    mapping(address => mapping(uint256 => TokenTypes.Locked[])) _lockedUsers;
    // playerFeeRatio
    uint24 internal _playerFeeRatio;
    // vaultMigrated
    bool internal _vaultMigrated;
    // trader order
    mapping(bytes32 => TokenTypes.TradeOrder) _tradeOrders;
}
