// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IEtherWrapper {
    function wrap(address weth, address to) external payable;

    function unwrap(
        address weth,
        address payable to,
        uint256 amount
    ) external;
}
