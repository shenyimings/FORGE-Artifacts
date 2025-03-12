// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAvtIou {
    function mint(address account, uint256 amount) external returns (bool);
}
