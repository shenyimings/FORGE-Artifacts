// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IDMMFactory {
    function createPool(
        IERC20 tokenA,
        IERC20 tokenB,
        uint32 ampBps
    ) external returns (address pool);

    function getFeeConfiguration() external view returns (address _feeAddress, uint16 _governmentFeeBps, uint16 _platformFeeBps);

    function getUnamplifiedPool(IERC20 token0, IERC20 token1) external view returns (address);

    function isPool(
        IERC20 token0,
        IERC20 token1,
        address pool
    ) external view returns (bool);

    function feeSetter() external view returns (address);

    function allPools(uint256) external view returns (address pool);

    event PoolCreated(
        IERC20 indexed token0,
        IERC20 indexed token1,
        address pool,
        uint32 ampBps,
        uint256 totalPool
    );

}
