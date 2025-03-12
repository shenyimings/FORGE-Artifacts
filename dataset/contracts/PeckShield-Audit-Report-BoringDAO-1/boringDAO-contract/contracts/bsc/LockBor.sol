// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LockBor is Ownable{

    using SafeERC20 for IERC20;

    IERC20 public bor;
    address public unlocker;

    event Lock(address locker, address recipient, uint amount);
    event Unlock(address recipient, uint amount);
    event ChangeAdmin(address oldAdmin, address newAdmin);

    constructor(address _bor, address _unlocker) public {
        bor = IERC20(_bor);
        unlocker = _unlocker;
    }

    function setAdmin(address account) public onlyOwner{
        address oldUnlocker = unlocker;
        unlocker = account;
        emit ChangeAdmin(oldUnlocker, account);
    }

    function lock(address recipient, uint amount) public {
        bor.safeTransferFrom(msg.sender, address(this), amount);
        emit Lock(msg.sender, recipient, amount);
    }

    function unlock(address recipient, uint amount) public {
        require(msg.sender == unlocker, "LockBor::unlock:only unlocker can unlock");
        bor.safeTransfer(recipient, amount);
        emit Unlock(recipient, amount);
    }
    
}