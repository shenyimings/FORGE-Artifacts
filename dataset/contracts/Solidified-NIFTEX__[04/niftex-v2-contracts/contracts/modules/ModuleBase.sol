// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../wallet/ShardedWallet.sol";
import "./IModule.sol";

abstract contract ModuleBase is IModule
{
    modifier onlyAuthorized(ShardedWallet wallet, address user)
    {
        require(wallet.governance().isAuthorized(address(wallet), user));
        _;
    }

    modifier onlyOwner(ShardedWallet wallet, address user)
    {
        require(wallet.owner() == user);
        _;
    }
}
