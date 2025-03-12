// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.0;

import {ThreeThreeTypes} from "../libraries/ThreeThreeTypes.sol";
import {LimitOrderTypes} from "../libraries/LimitOrderTypes.sol";
import {WatchlistTypes} from "../libraries/WatchlistTypes.sol";

abstract contract AlphaKeysFactoryStorage {
    //
    address internal _playerShareTokenImplementation;
    //
    uint24 internal _protocolFeeRatio;
    uint24 internal _playerFeeRatio;
    address internal _protocolFeeDestination;
    //
    mapping(address => address) internal _playerKeys;
    mapping(address => address) internal _keysPlayers;
    mapping(uint256 => address) internal _twitterKeys;
    mapping(address => uint256) internal _keysTwitters;
    //
    address internal _admin;
    address internal _btc;
    uint256 internal _btcPrice;
    // for gas
    mapping(address => mapping(uint256 => bool)) _usedNonces;
    // three three model
    mapping(bytes32 => ThreeThreeTypes.Order) _threeThreeOrders;
    // vault address
    address internal _vault;
    address internal _swapRouter;
    // limit orders
    mapping(address => mapping(uint256 => LimitOrderTypes.Order)) _limitOrders;
    // watchlist model : trader -> player
    mapping(uint256 => mapping(uint256 => WatchlistTypes.Watchlist)) _watchlists;
    mapping(uint256 => mapping(bytes32 => bool)) _copyTrades;
}
