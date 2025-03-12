// SPDX-License-Identifier: MIT
import "./interfaces/IPriceManager.sol";
import "./interfaces/IPositionVault.sol";
import "./interfaces/IOperators.sol";
import "./interfaces/IOrderVault.sol";
import "./interfaces/ILiquidateVault.sol";
import "./interfaces/IExtentedPyth.sol";

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

pragma solidity 0.8.9;

contract OrderExecutor is Initializable {
    IOperators public operators;

    IPriceManager private priceManager;
    IPositionVault private positionVault;
    IOrderVault private orderVault;
    ILiquidateVault private liquidateVault;
    uint256 internal constant BASIS_POINTS_DIVISOR = 100000;

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

    modifier setPrice(uint256[] memory _assets, uint256[] memory _prices, uint256 _timestamp, bytes[] calldata _updateData) {
        require(_assets.length == _prices.length, 'invalid length');
        require(block.timestamp >= _timestamp, 'invalid timestamp');
        if (_updateData.length > 0) {
            priceManager.pyth().updatePriceFeeds{value : msg.value}(_updateData);
        }
        for (uint256 i = 0; i < _assets.length; i++) {
            priceManager.setPrice(_assets[i], _prices[i], _timestamp);
        }
        _;
    }


    function setPricesAndExecuteOrders(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256 _numPositions,
        bytes[] calldata _updateData
    ) external payable onlyOperator(1) setPrice(_assets, _prices, _timestamp, _updateData) {
        positionVault.executeOrders(_numPositions);
    }


    function setPricesAndTriggerForOpenOrders(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _posIds,
        bytes[] calldata _updateData
    ) external payable onlyOperator(1) setPrice(_assets, _prices, _timestamp, _updateData) {
        for (uint256 i = 0; i < _posIds.length; i++) {
            orderVault.triggerForOpenOrders(_posIds[i]);
        }
    }

    function setPricesAndTriggerForTPSL(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _tpslPosIds,
        bytes[] calldata _updateData
    ) external payable onlyOperator(1) setPrice(_assets, _prices, _timestamp, _updateData) {
        for (uint256 i = 0; i < _tpslPosIds.length; i++) {
            orderVault.triggerForTPSL(_tpslPosIds[i]);
        }
    }

    function setPricesAndTrigger(
        uint256[] memory _assets,
        uint256[] memory _prices,
        uint256 _timestamp,
        uint256[] memory _posIds,
        uint256[] memory _tpslPosIds,
        bytes[] calldata _updateData
    ) external payable onlyOperator(1) setPrice(_assets, _prices, _timestamp, _updateData) {
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
        uint256[] memory _posIds,
        bytes[] calldata _updateData
    ) external payable onlyOperator(1) setPrice(_assets, _prices, _timestamp, _updateData) {
        for (uint256 i = 0; i < _posIds.length; i++) {
            liquidateVault.liquidatePosition(_posIds[i]);
        }
    }

    function getUpdateFee(
        bytes[] calldata updateData
    ) external view returns (uint feeAmount) {
        IPyth pyth = priceManager.pyth();
        return pyth.getUpdateFee(updateData);
    }

    function getListInvalidPythPrice(
        uint256[] memory _assets,
        uint256[] memory _prices) public view returns (bool[] memory results, bytes32[] memory pythIds) {
        pythIds = new bytes32[](_assets.length);
        results = new bool[](_assets.length);
        IPyth pyth = priceManager.pyth();
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 _assetId = _assets[i];
            uint256 _price = _prices[i];
            bytes32 pythId;
            uint256 allowedStaleness;
            uint256 allowedDeviation;
            (, pythId,,,allowedStaleness,allowedDeviation,,) = priceManager.assets(_assetId);
            bool needUpdate = false;
            if (pythId != bytes32(0)) {

                if (IExtentedPyth(address(pyth)).priceFeedExists(pythId)) {
                    PythStructs.Price memory priceInfo = pyth.getPriceUnsafe(pythId);
                    if (block.timestamp > priceInfo.publishTime + allowedStaleness) {
                        needUpdate = true;
                    } else {
                        uint256 priceOnChain = priceManager.getPythLastPrice(_assetId, false);
                        uint256 deviation = _price > priceOnChain
                        ? ((_price - priceOnChain) * BASIS_POINTS_DIVISOR) / priceOnChain
                        : ((priceOnChain - _price) * BASIS_POINTS_DIVISOR) / priceOnChain;
                        needUpdate = deviation > allowedDeviation;
                    }
                } else {
                    needUpdate = true;
                }
            }
            pythIds[i] = pythId;
            results[i] = needUpdate;
        }
    }


    function getTokenIdsOfUnExecuteOrders(uint256 maxNumOfOrders) public view returns (uint256, uint256[] memory) {
        uint256 _num = positionVault.getNumOfUnexecuted();
        uint256 numOfOrders = _num > maxNumOfOrders ? maxNumOfOrders : _num;
        uint256 index = positionVault.queueIndex();
        uint256 endIndex = index + numOfOrders;
        uint256 length = positionVault.getNumOfUnexecuted() + index;
        if (endIndex > length) endIndex = length;
        uint256[] memory tokenIds = new uint256[](endIndex - index);
        uint256 p = 0;
        while (index < endIndex) {
            uint256 t = positionVault.queuePosIds(index);
            uint256 posId = t % 2 ** 128;
            tokenIds[p] = positionVault.getPosition(posId).tokenId;
            ++index;
            ++p;
        }
        return (numOfOrders, tokenIds);
    }


}