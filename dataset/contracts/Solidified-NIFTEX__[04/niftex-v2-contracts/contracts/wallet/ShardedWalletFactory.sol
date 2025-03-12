// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/CloneFactory.sol";
import "./ShardedWallet.sol";

contract ShardedWalletFactory is CloneFactory
{
    constructor()
    CloneFactory(address(new ShardedWallet()))
    {}

    function mintWallet(
        address               governance_,
        address               owner_,
        string       calldata name_,
        string       calldata symbol_,
        address               artistWallet_
    )
    external returns (address instance)
    {
        instance = _clone();
        ShardedWallet(payable(instance)).initialize(governance_, owner_, name_, symbol_, artistWallet_);
    }
}
