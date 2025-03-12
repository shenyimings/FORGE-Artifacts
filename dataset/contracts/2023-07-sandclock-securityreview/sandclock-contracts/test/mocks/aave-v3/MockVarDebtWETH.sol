// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {MockAavePool} from "./MockAavePool.sol";
import {MockWETH} from "../MockWETH.sol";

contract MockVarDebtWETH {
    MockAavePool public aavePool;
    MockWETH public mockWeth;

    constructor(MockAavePool _aavePool, MockWETH _mockWeth) {
        aavePool = _aavePool;
        mockWeth = _mockWeth;
    }

    function balanceOf(address account) external view returns (uint256) {
        (, uint256 borrowAmount) = aavePool.book(account, address(mockWeth));
        return borrowAmount;
    }
}
