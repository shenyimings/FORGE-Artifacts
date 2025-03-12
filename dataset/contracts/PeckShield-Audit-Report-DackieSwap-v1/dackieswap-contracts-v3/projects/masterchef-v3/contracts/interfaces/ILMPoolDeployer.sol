// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IDackieV3Pool.sol";
import "./ILMPool.sol";

interface ILMPoolDeployer {
    function deploy(IDackieV3Pool pool) external returns (ILMPool lmPool);
}
