// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './NonfungiblePositionManagerMock.sol';

contract MockTimeNonfungiblePositionManagerMock is NonfungiblePositionManagerMock {
    uint256 time;

    constructor(
        address _deployer,
        address _factory,
        address _WETH9,
        address _tokenDescriptor
    ) NonfungiblePositionManagerMock(_deployer, _factory, _WETH9, _tokenDescriptor) {}

    function _blockTimestamp() internal view returns (uint256) {
        return time;
    }

    function setTime(uint256 _time) external {
        time = _time;
    }
}
