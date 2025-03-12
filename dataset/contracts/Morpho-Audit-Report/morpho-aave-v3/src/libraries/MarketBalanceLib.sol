// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import {Types} from "./Types.sol";

import {LogarithmicBuckets} from "@morpho-data-structures/LogarithmicBuckets.sol";

/// @title MarketBalanceLib
/// @author Morpho Labs
/// @custom:contact security@morpho.xyz
/// @notice Library used to ease market balance reads.
library MarketBalanceLib {
    /// @notice Returns the scaled pool supply balance of `user` given the `marketBalances` of a specific market.
    function scaledPoolSupplyBalance(Types.MarketBalances storage marketBalances, address user)
        internal
        view
        returns (uint256)
    {
        return marketBalances.poolSuppliers.valueOf[user];
    }

    /// @notice Returns the scaled peer-to-peer supply balance of `user` given the `marketBalances` of a specific market.
    function scaledP2PSupplyBalance(Types.MarketBalances storage marketBalances, address user)
        internal
        view
        returns (uint256)
    {
        return marketBalances.p2pSuppliers.valueOf[user];
    }

    /// @notice Returns the scaled pool borrow balance of `user` given the `marketBalances` of a specific market.
    function scaledPoolBorrowBalance(Types.MarketBalances storage marketBalances, address user)
        internal
        view
        returns (uint256)
    {
        return marketBalances.poolBorrowers.valueOf[user];
    }

    /// @notice Returns the scaled peer-to-peer borrow balance of `user` given the `marketBalances` of a specific market.
    function scaledP2PBorrowBalance(Types.MarketBalances storage marketBalances, address user)
        internal
        view
        returns (uint256)
    {
        return marketBalances.p2pBorrowers.valueOf[user];
    }

    /// @notice Returns the scaled collateral balance of `user` given the `marketBalances` of a specific market.
    function scaledCollateralBalance(Types.MarketBalances storage marketBalances, address user)
        internal
        view
        returns (uint256)
    {
        return marketBalances.collateral[user];
    }
}
