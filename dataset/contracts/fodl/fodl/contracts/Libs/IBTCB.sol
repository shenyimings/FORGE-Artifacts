// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IBTCB is ERC20 {
    function mint(uint256 amount) external virtual returns (bool);

    function owner() external view virtual returns (address);
}
