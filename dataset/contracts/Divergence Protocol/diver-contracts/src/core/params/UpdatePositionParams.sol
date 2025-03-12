// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import { ModifyPositionParams } from "./ModifyPositionParams.sol";

struct UpdatePositionParams {
    ModifyPositionParams mpParams;
    int24 tick;
}
