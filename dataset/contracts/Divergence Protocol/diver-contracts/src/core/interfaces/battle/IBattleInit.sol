// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { DeploymentParams } from "../../params/DeploymentParams.sol";

interface IBattleInit {
    function initState(DeploymentParams memory params) external;
    function init(uint160 startSqrtPriceX96) external;
}
