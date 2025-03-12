// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IPeripheryImmutableState } from "../interfaces/IPeripheryImmutableState.sol";

abstract contract PeripheryImmutableState is IPeripheryImmutableState {
    address public immutable arena;
    address public immutable WETH9;

    constructor(address _arena, address _WETH9) {
        arena = _arena;
        WETH9 = _WETH9;
    }
}
