// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IDOLA is ERC20 {
    function mint(address to, uint256 amount) external virtual;
}
