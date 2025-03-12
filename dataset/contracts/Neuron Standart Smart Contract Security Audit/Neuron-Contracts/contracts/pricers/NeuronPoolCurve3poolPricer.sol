// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import {IPricer} from "../interfaces/IPricer.sol";
import {INeuronPool} from "../interfaces/INeuronPool.sol";
import {IOracle} from "../interfaces/IOracle.sol";

contract NeuronPoolCurve3poolPricer is IPricer {
    address public constant CRV3 = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;

    address public asset;

    INeuronPool public immutable NEURON_POOL;

    IPricer public immutable CRV3_PRICER;

    uint8 public pricePerShareDecimals;

    IOracle public oracle;

    constructor(
        address _neuronPool,
        address _crv3Pricer,
        uint8 _pricePerShareDecimals,
        address _oracle
    ) {
        asset = _neuronPool;
        NEURON_POOL = INeuronPool(_neuronPool);
        CRV3_PRICER = IPricer(_crv3Pricer);
        pricePerShareDecimals = _pricePerShareDecimals;
        oracle = IOracle(_oracle);
    }

    function getPrice() external view override returns (uint256) {
        return _getPrice(CRV3_PRICER.getPrice());
    }

    function _getPrice(uint256 _crv3Price) private view returns (uint256) {
        return (NEURON_POOL.pricePerShare() * _crv3Price) / 10**pricePerShareDecimals;
    }

    function setExpiryPriceInOracle(uint256 _expiryTimestamp) external {
        (uint256 crv3PriceExpiry, ) = oracle.getExpiryPrice(CRV3, _expiryTimestamp);

        require(crv3PriceExpiry > 0, "3CRV price not set yet");

        uint256 price = _getPrice(crv3PriceExpiry);

        oracle.setExpiryPrice(asset, _expiryTimestamp, price);
    }
}
