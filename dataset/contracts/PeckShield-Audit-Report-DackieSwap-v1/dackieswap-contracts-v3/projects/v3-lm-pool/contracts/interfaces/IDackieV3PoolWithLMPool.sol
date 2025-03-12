// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;
import '@pancakeswap/v3-core/contracts/interfaces/IDackieV3Pool.sol';

interface IDackieV3PoolWithLMPool is IDackieV3Pool {
    function lmPool() external view returns (address);
}