// SPDX-License-Identifier: GPL-2.0

pragma solidity 0.7.6;
pragma abicoder v2;

import '../../interfaces/IUniswapAddressHolder.sol';
import '../../interfaces/IRegistry.sol';

contract UniswapAddressHolder is IUniswapAddressHolder {
    address public override nonfungiblePositionManagerAddress;
    address public override uniswapV3FactoryAddress;
    address public override swapRouterAddress;
    IRegistry public registry;

    constructor(
        address _nonfungiblePositionManagerAddress,
        address _uniswapV3FactoryAddress,
        address _swapRouterAddress,
        address _registry
    ) {
        nonfungiblePositionManagerAddress = _nonfungiblePositionManagerAddress;
        uniswapV3FactoryAddress = _uniswapV3FactoryAddress;
        swapRouterAddress = _swapRouterAddress;
        registry = IRegistry(_registry);
    }

    ///@notice Set the address of the non fungible position manager
    ///@param newAddress The address of the non fungible position manager
    function setNonFungibleAddress(address newAddress) external override onlyGovernance {
        nonfungiblePositionManagerAddress = newAddress;
    }

    ///@notice Set the address of the Uniswap V3 factory
    ///@param newAddress The address of the Uniswap V3 factory
    function setFactoryAddress(address newAddress) external override onlyGovernance {
        uniswapV3FactoryAddress = newAddress;
    }

    ///@notice Set the address of the swap router
    ///@param newAddress The address of the swap router
    function setSwapRouterAddress(address newAddress) external override onlyGovernance {
        swapRouterAddress = newAddress;
    }

    ///@notice Set the address of the registry
    ///@param newAddress The address of the registry
    function setRegistry(address newAddress) external override onlyGovernance {
        registry = IRegistry(newAddress);
    }

    ///@notice restrict some function called only by governance
    modifier onlyGovernance() {
        require(
            msg.sender == registry.governance(),
            'AaveAddressHolder::onlyGovernance:  Only governance can call this function'
        );
        _;
    }
}
