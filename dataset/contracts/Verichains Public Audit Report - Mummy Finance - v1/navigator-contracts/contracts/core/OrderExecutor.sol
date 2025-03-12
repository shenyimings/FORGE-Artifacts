// SPDX-License-Identifier: MIT
import "./interfaces/IPriceManager.sol";
import "./interfaces/IPositionVault.sol";
import "./interfaces/IOperators.sol";
import "./interfaces/IOrderVault.sol";
import "./interfaces/ILiquidateVault.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

pragma solidity 0.8.9;

contract OrderExecutor is Initializable {
    IOperators public operators;

    IPriceManager private priceManager;
    IPositionVault private positionVault;
    IOrderVault private orderVault;
    ILiquidateVault private liquidateVault;

    function initialize(IPriceManager _priceManager,
        IPositionVault _positionVault,
        IOrderVault _orderVault,
        IOperators _operators,
        ILiquidateVault _liquidateVault
    ) public initializer {
        require(AddressUpgradeable.isContract(address(_priceManager)), "priceManager invalid");
        require(AddressUpgradeable.isContract(address(_positionVault)), "positionVault invalid");
        require(AddressUpgradeable.isContract(address(_orderVault)), "orderVault invalid");
        require(AddressUpgradeable.isContract(address(_operators)), "operators is invalid");
        require(AddressUpgradeable.isContract(address(_liquidateVault)), "liquidateVault is invalid");

        priceManager = _priceManager;
        orderVault = _orderVault;
        positionVault = _positionVault;
        operators = _operators;
        liquidateVault = _liquidateVault;
    }

    modifier onlyOperator(uint256 level) {
        _onlyOperator(level);
        _;
    }

    function _onlyOperator(uint256 level) private view {
        require(operators.getOperatorLevel(msg.sender) >= level, "invalid operator");
    }

    modifier setPrice(uint256[] memory _assets, uint256[] memory _prices, uint256 _timestamp) {
        require(_assets.length == _prices.length, 'invalid length');
        require(block.timestamp >= _timestamp, 'invalid timestamp');
        for (uint256 i = 0; i < _assets.length; i++) {
            priceManager.setPrice(_assets[i], _prices[i], _timestamp);
        }
        _;
    }


    function setPricesAndExecuteOrders(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256 _numPositions
    ) external onlyOperator(1) setPrice(_assets, _prices, _timestamp) {
        positionVault.executeOrders(_numPositions);
    }


    function setPricesAndTriggerForOpenOrders(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _posIds
    ) external onlyOperator(1) setPrice(_assets, _prices, _timestamp) {
        for (uint256 i = 0; i < _posIds.length; i++) {
            orderVault.triggerForOpenOrders(_posIds[i]);
        }
    }

    function setPricesAndTriggerForTPSL(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _tpslPosIds
    ) external onlyOperator(1) setPrice(_assets, _prices, _timestamp) {
        for (uint256 i = 0; i < _tpslPosIds.length; i++) {
            orderVault.triggerForTPSL(_tpslPosIds[i]);
        }
    }
    function setPricesAndTrigger(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _posIds,
        uint256[] memory _tpslPosIds
    ) external onlyOperator(1) setPrice(_assets, _prices, _timestamp) {
        for (uint256 i = 0; i < _posIds.length; i++) {
            orderVault.triggerForOpenOrders(_posIds[i]);
        }
        for (uint256 i = 0; i < _tpslPosIds.length; i++) {
            orderVault.triggerForTPSL(_tpslPosIds[i]);
        }
    }
    function setPricesAndLiquidatePositions(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _posIds
    ) external onlyOperator(1) setPrice(_assets, _prices, _timestamp) {
        for (uint256 i = 0; i < _posIds.length; i++) {
            liquidateVault.liquidatePosition(_posIds[i]);
        }
    }
}