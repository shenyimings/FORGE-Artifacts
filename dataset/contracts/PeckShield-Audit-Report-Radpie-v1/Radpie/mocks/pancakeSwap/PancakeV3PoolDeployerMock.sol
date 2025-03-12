// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPancakeV3PoolDeployer,PancakeV3Pool  } from './PancakeV3PoolMock.sol';

contract PancakeV3PoolDeployer is IPancakeV3PoolDeployer {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public override parameters;

    address public factoryAddress;

    /// @notice Emitted when factory address is set
    event SetFactoryAddress(address indexed factory);

    modifier onlyFactory() {
        require(msg.sender == factoryAddress, "only factory can call deploy");
        _;
    }

    function setFactoryAddress(address _factoryAddress) external {
        require(factoryAddress == address(0), "already initialized");

        factoryAddress = _factoryAddress;

        emit SetFactoryAddress(_factoryAddress);
    }

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) external override returns (address pool) {
        parameters = Parameters({factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing});
        pool = address(new PancakeV3Pool{salt: keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }
}