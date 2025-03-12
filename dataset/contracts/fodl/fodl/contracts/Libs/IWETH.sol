// SPDX-License-Identifier: MIT
// Taken from: https://github.com/aave/protocol-v2/blob/master/contracts/misc/interfaces/IWETH.sol

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IWETH is ERC20 {
    function deposit() external payable virtual;

    function withdraw(uint256 wad) external virtual;
}
