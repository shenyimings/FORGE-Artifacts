// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IPancakeV3Factory {
    struct TickSpacingExtraInfo {
        bool whitelistRequested;
        bool enabled;
    }

    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    event FeeAmountExtraInfoUpdated(uint24 indexed fee, bool whitelistRequested, bool enabled);

    event WhiteListAdded(address indexed user, bool verified);

    event SetLmPoolDeployer(address indexed lmPoolDeployer);

    function owner() external view returns (address);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    function feeAmountTickSpacingExtraInfo(uint24 fee) external view returns (bool whitelistRequested, bool enabled);

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);


    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    function setOwner(address _owner) external;

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;


    function setWhiteListAddress(address user, bool verified) external;

    function setFeeAmountExtraInfo(
        uint24 fee,
        bool whitelistRequested,
        bool enabled
    ) external;

    function setLmPoolDeployer(address _lmPoolDeployer) external;

    function setFeeProtocol(address pool, uint32 feeProtocol0, uint32 feeProtocol1) external;

    function collectProtocol(
        address pool,
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    function setLmPool(address pool, address lmPool) external;
}

interface IPoolInitializerMock {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}

interface IPeripheryImmutableStateMock {
    function deployer() external view returns (address);
    function factory() external view returns (address);
    function WETH9() external view returns (address);
}

// abstract contract PeripheryImmutableStateMock is IPeripheryImmutableStateMock {
//     /// @inheritdoc IPeripheryImmutableStateMock
//     address public immutable override deployer;
//     /// @inheritdoc IPeripheryImmutableStateMock
//     address public immutable override factory;
//     /// @inheritdoc IPeripheryImmutableStateMock
//     address public immutable override WETH9;

//     constructor(address _deployer, address _factory, address _WETH9) {
//         deployer = _deployer;
//         factory = _factory;
//         WETH9 = _WETH9;
//     }
// }

import { PeripheryImmutableStateMock } from './PeripheryImmutableStateMock.sol';
import { IPancakeV3Pool } from './LiquidityManagementMock.sol';

import "hardhat/console.sol";

abstract contract PoolInitializerMock is PeripheryImmutableStateMock {
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool) {
        // require(token0 < token1);
        // pool = IPancakeV3Factory(factory).getPool(token0, token1, fee);

        // if (pool == address(0)) {
            pool = IPancakeV3Factory(factory).createPool(token0, token1, fee);
            // console.log(pool);
        //     IPancakeV3Pool(pool).initialize(sqrtPriceX96);
        // } else {
        //     (uint160 sqrtPriceX96Existing, , , , , , ) = IPancakeV3Pool(pool).slot0();
        //     if (sqrtPriceX96Existing == 0) {
        //         IPancakeV3Pool(pool).initialize(sqrtPriceX96);
        //     }
        // }
    }
}