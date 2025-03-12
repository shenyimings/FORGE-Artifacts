// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import './interfaces/IOpenSkyPriceAggregator.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

interface AggregatorInterface {
    function latestAnswer() external view returns (int256);
}

/**
 * @title OpenSkyPriceAggregator Contract
 * @author OpenSky Labs
 * @notice Proxy smart contract to get the price of a nft from a price aggregator, with Chainlink Aggregator
 *         smart contracts as primary option
 * - Owned by the OpenSky governance system, allowed to add aggregators for nfts, replace them
 **/
contract OpenSkyPriceAggregator is IOpenSkyPriceAggregator, Ownable {
    mapping (address => AggregatorInterface) public aggregators;

    constructor() Ownable() {}

    /**
     * @notice External function called by the OpenSky governance to set or replace price aggregators of assets
     * @param assets The addresses of the assets
     * @param _aggregators The address of the source of each asset
     **/
    function setAggregators(address[] memory assets, AggregatorInterface[] memory _aggregators) public onlyOwner {
        require(assets.length == _aggregators.length, 'INCONSISTENT_PARAMS_LENGTH');
        for (uint256 i = 0; i < assets.length; i++) {
            require(address(_aggregators[i]) != address(0), 'AGGREGATOR_CAN_NOT_BE_ZERO_ADDRESS');
            _setAggregator(assets[i], _aggregators[i]);
        }
    }

    /**
     * @notice Internal function to set the sources for each asset
     * @param asset The address of the nft collection address
     * @param aggregator The address of the aggregator
     **/
    function _setAggregator(address asset, AggregatorInterface aggregator) internal {
        aggregators[asset] = aggregator;
        emit SetAggregator(asset, address(aggregator));
    }

    /**
     * @notice Gets the nft floor price by address
     * @param asset The nft collection address
    **/
    function getAssetPrice(address asset) external view override returns (uint256) {
        if (address(aggregators[asset]) == address(0)) {
            return 0;
        }
        return uint256(aggregators[asset].latestAnswer());
    }
}
