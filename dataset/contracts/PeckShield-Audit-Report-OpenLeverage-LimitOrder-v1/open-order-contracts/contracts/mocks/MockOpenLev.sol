// SPDX-License-Identifier: BUSL-1.1
pragma solidity >0.7.6;

import "../interfaces/OpenLevInterface.sol";
import "../interfaces/DexAggregatorInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma experimental ABIEncoderV2;

contract MockOpenLev is OpenLevInterface {
    uint16 public marketId;
    mapping(uint16 => OpenLevInterface.Market) private _markets;
    uint256 public newHeld;
    uint256 public depositReturn;
    DexAggregatorInterface public dexAgg;
    mapping(address => mapping(uint16 => mapping(bool => OpenLevInterface.Trade))) private _activeTrades;

    constructor(DexAggregatorInterface _dexAgg) {
        dexAgg = _dexAgg;
    }

    function createMarket(address token0, address token1) external {
        _markets[marketId] = OpenLevInterface.Market(address(0), address(0), token0, token1, 0, 0, 0, address(0), 0, 0, new uint32[](0));
        marketId++;
    }

    function setNewHeld(uint256 _newHeld) external {
        newHeld = _newHeld;
    }

    function setDepositReturn(uint256 _depositReturn) external {
        depositReturn = _depositReturn;
    }

    function markets(uint16 _marketId) external view override returns (OpenLevInterface.Market memory market) {
        market = _markets[_marketId];
    }

    function activeTrades(
        address trader,
        uint16 _marketId,
        bool longToken
    ) external view returns (Trade memory trade) {
        trade = _activeTrades[trader][_marketId][longToken];
    }

    function updatePrice(uint16 _marketId, bytes memory dexData) external override {
        dexData;
        OpenLevInterface.Market memory market = _markets[_marketId];
        dexAgg.updatePriceOracle(market.token0, market.token1, 60, hex"00");
    }

    function marginTradeFor(
        address trader,
        uint16 _marketId,
        bool longToken,
        bool depositToken,
        uint256 deposit,
        uint256 borrow,
        uint256 minBuyAmount,
        bytes memory dexData
    ) external payable override returns (uint256) {
        borrow;
        minBuyAmount;
        dexData;
        depositToken == false
            ? IERC20(_markets[_marketId].token0).transferFrom(msg.sender, address(this), deposit)
            : IERC20(_markets[_marketId].token1).transferFrom(msg.sender, address(this), deposit);
        Trade storage trade = _activeTrades[trader][_marketId][longToken];
        trade.held += newHeld;
        trade.depositToken = depositToken;
        trade.deposited += deposit;
        trade.lastBlockNum = uint128(block.number);
        return newHeld;
    }

    function closeTradeFor(
        address trader,
        uint16 _marketId,
        bool longToken,
        uint256 closeHeld,
        uint256 minOrMaxAmount,
        bytes memory dexData
    ) external override returns (uint256) {
        minOrMaxAmount;
        dexData;
        Trade storage trade = _activeTrades[trader][_marketId][longToken];
        trade.depositToken == false
            ? IERC20(_markets[_marketId].token0).transfer(trader, depositReturn)
            : IERC20(_markets[_marketId].token1).transfer(trader, depositReturn);
        if (trade.held == closeHeld) {
            delete _activeTrades[trader][_marketId][longToken];
        } else {
            trade.held -= closeHeld;
            trade.deposited -= (trade.deposited * closeHeld) / trade.held;
        }
        return depositReturn;
    }
}
