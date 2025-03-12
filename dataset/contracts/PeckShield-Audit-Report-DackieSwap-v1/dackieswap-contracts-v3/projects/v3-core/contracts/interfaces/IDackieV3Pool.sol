// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IDackieV3PoolImmutables.sol';
import './pool/IDackieV3PoolState.sol';
import './pool/IDackieV3PoolDerivedState.sol';
import './pool/IDackieV3PoolActions.sol';
import './pool/IDackieV3PoolOwnerActions.sol';
import './pool/IDackieV3PoolEvents.sol';

/// @title The interface for a DackieSwap V3 Pool
/// @notice A DackieSwap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IDackieV3Pool is
    IDackieV3PoolImmutables,
    IDackieV3PoolState,
    IDackieV3PoolDerivedState,
    IDackieV3PoolActions,
    IDackieV3PoolOwnerActions,
    IDackieV3PoolEvents
{

}
