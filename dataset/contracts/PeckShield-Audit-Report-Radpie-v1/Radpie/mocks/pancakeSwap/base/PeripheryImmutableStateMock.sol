// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPeripheryImmutableStateMock {
    function deployer() external view returns (address);
    function factory() external view returns (address);
    function WETH9() external view returns (address);
}

abstract contract PeripheryImmutableStateMock is IPeripheryImmutableStateMock {
    address public immutable override deployer;
    address public immutable override factory;
    address public immutable override WETH9;

    constructor(address _deployer, address _factory, address _WETH9) {
        deployer = _deployer;
        factory = _factory;
        WETH9 = _WETH9;
    }
}