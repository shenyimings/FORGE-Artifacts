// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IPricer} from "../interfaces/IPricer.sol";
import {ICurvePool} from "../interfaces/ICurve.sol";
import {INeuronPool} from "../interfaces/INeuronPool.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IOracle} from "../interfaces/IOracle.sol";

contract NeuronPoolCurveLUSDPricer is IPricer {
    address public constant CRV3 = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address public constant LUSD = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;

    ITroveManager public constant TROVE_MANAGER = ITroveManager(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);

    ICurvePool public constant CURVE_POOL = ICurvePool(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);

    address public immutable asset;

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
        return _getPrice(CRV3_PRICER.getPrice() * 1e10, _getLUSDPrice());
    }

    function _getPrice(uint256 _crv3Price, uint256 _lusdPrice) private view returns (uint256) {
        _crv3Price = _crv3Price * 1e10;
        return
            (NEURON_POOL.pricePerShare() *
                CURVE_POOL.get_virtual_price() *
                (_crv3Price < _lusdPrice ? _crv3Price : _lusdPrice)) / (10**(pricePerShareDecimals + 28));
    }

    function _getLUSDPrice() private view returns (uint256) {
        return 1e18 - TROVE_MANAGER.getRedemptionRate();
    }

    function setExpiryPriceInOracle(uint256 _expiryTimestamp) external {
        (uint256 crv3PriceExpiry, ) = oracle.getExpiryPrice(CRV3, _expiryTimestamp);
        require(crv3PriceExpiry > 0, "3CRV token price not set yet");

        uint256 lusdPriceExpiry = _getLUSDPrice();
        require(lusdPriceExpiry > 0, "LUSD price not set yet");

        uint256 price = _getPrice(crv3PriceExpiry, lusdPriceExpiry);

        oracle.setExpiryPrice(asset, _expiryTimestamp, price);
    }
}
