// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import {TokenInterface} from "../../common/interfaces.sol";
import {DSMath} from "../../common/math.sol";
import {Basic} from "../../common/basic.sol";
import "./interface.sol";

abstract contract Helpers is DSMath, Basic {
    IGraphProtocolInterface public constant graphProxy =
        IGraphProtocolInterface(0xF55041E37E12cD407ad00CE2910B8269B01263b9);

    TokenInterface public constant grtTokenAddress =
        TokenInterface(0xc944E90C64B2c07662A292be6244BDf05Cda44a7);
}
