// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {MockAavePool} from "./MockAavePool.sol";
import {MockWstETH} from "../lido/MockWstETH.sol";

contract MockAwstETH {
    MockAavePool public aavePool;
    MockWstETH public mockWstEth;

    constructor(MockAavePool _aavePool, MockWstETH _mockWstEth) {
        aavePool = _aavePool;
        mockWstEth = _mockWstEth;
    }

    function balanceOf(address account) external view returns (uint256) {
        (uint256 supplyAmount,) = aavePool.book(account, address(mockWstEth));
        return supplyAmount;
    }
}
