// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ModuleBase.sol";

contract ERC20ManagerModule is IModule, ModuleBase
{
    string public constant override name = type(ERC20ManagerModule).name;

    function mint(address account, uint256 amount) public {
        ShardedWallet(payable(msg.sender)).moduleMint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        ShardedWallet(payable(msg.sender)).moduleBurn(account, amount);
    }

    function transfer(address from, address to, uint256 amount) public {
        ShardedWallet(payable(msg.sender)).moduleTransfer(from, to, amount);
    }
}
