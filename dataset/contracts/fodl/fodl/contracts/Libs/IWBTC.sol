// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IWBTC is ERC20 {
    function owner() external view virtual returns (address);

    function mint(address to, uint256 amount) external virtual;

    function mintingFinished() external view virtual returns (bool);
}
