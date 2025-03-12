// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IDAI is ERC20 {
    function wards(address) external view virtual returns (uint256);

    function mint(address to, uint256 amount) external virtual;
}
