// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/IStabilityPool.sol";

contract StabilityPoolScript {
    bytes32 public constant NAME = "StabilityPoolScript";

    IStabilityPool immutable stabilityPool;

    constructor(IStabilityPool _stabilityPool) {
        stabilityPool = _stabilityPool;
    }

    function provideToSP(uint256 _amount, address _frontEndTag) external {
        stabilityPool.provideToSP(_amount, _frontEndTag);
    }

    function withdrawFromSP(uint256 _amount) external {
        stabilityPool.withdrawFromSP(_amount);
    }
}
