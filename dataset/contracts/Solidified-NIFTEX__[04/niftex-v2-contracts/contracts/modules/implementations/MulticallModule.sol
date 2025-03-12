// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma abicoder v2;

import "../ModuleBase.sol";

contract MulticallModule is IModule, ModuleBase
{
    string public constant override name = type(MulticallModule).name;

    function batch(ShardedWallet wallet, address[] calldata to, uint256[] calldata value, bytes[] calldata data)
    external onlyOwner(wallet, msg.sender)
    {
        require(to.length == value.length);
        require(to.length == data.length);
        for (uint256 i = 0; i < to.length; ++i)
        {
            wallet.moduleExecute(to[i], value[i], data[i]);
        }
    }
}
