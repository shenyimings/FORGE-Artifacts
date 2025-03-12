// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVemnt {
    function deposit(uint256 amount) external;
}

contract MockPiston {

    IVemnt public vemnt;
    IERC20 public mnt;

    constructor(address _mnt, address _vemnt) {
        vemnt = IVemnt(_vemnt);
        mnt = IERC20(_mnt);
    }

    function stake(uint amount) external {
        mnt.approve(address(vemnt), amount);
        vemnt.deposit(amount);
    }
}