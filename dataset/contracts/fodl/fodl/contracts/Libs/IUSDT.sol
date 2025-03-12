// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

abstract contract IUSDT is ERC20 {
    function getOwner() external view virtual returns (address);

    function issue(uint256 amount) external virtual;
}
