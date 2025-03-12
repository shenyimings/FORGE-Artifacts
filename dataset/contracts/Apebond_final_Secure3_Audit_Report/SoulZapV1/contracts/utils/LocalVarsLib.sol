// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

library LocalVarsLib {
    struct LocalVars {
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;
        uint256 amount0Lp;
        uint256 amount1Lp;
    }
}
