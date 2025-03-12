// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "../ModuleBase.sol";

struct Allocation
{
    address receiver;
    uint256 amount;
}

contract BasicDistributionModule is IModule, ModuleBase
{
    string public constant override name = type(BasicDistributionModule).name;

    function setup(ShardedWallet wallet, Allocation[] calldata mints)
    external onlyOwner(wallet, msg.sender)
    {
        require(wallet.totalSupply() == 0);
        wallet.moduleTransferOwnership(address(0));
        for (uint256 i = 0; i < mints.length; ++i)
        {
            wallet.moduleMint(mints[i].receiver, mints[i].amount);
        }
    }
}
