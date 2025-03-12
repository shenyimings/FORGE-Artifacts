//SPDX-License-Identifier: MIT

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import "./LimitOrderBook.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

import { Decimal } from "./utils/Decimal.sol";
import { SignedDecimal } from "./utils/SignedDecimal.sol";
import { DecimalERC20 } from "./utils/DecimalERC20.sol";

import { IAmm } from "./interface/IAmm.sol";
import { IClearingHouse } from "./interface/IClearingHouse.sol";
import { ISmartWallet } from "./interface/ISmartWallet.sol";

contract SmartWallet is DecimalERC20, Initializable, ISmartWallet, Pausable {

  // Store addresses of smart contracts that we will be interacting with
  LimitOrderBook public OrderBook;
  SmartWalletFactory public factory;
  address constant CLEARINGHOUSE = 0x5d9593586b4B5edBd23E7Eba8d88FD8F09D83EBd;

  address private owner;

  using Decimal for Decimal.decimal;
  using SignedDecimal for SignedDecimal.signedDecimal;
  using Address for address;
  using SafeERC20 for IERC20;

  /*
   * @notice allows the owner of the smart wallet to execute any transaction
   *  on an external smart contract. There are no restrictions on the contracts
   *  that the user can interact with so needs to make sure that they do not
   *  interact with any malicious contracts.
   *  This utilises functions from OpenZeppelin's Address.sol
   * @param target the address of the smart contract to interact with (will revert
   *    if this is not a valid smart contract)
   * @param callData the data bytes of the function and parameters to execute
   *    Can use encodeFunctionData() from ethers.js
   */

  function executeCall(
    address target,
    bytes calldata callData
  ) external override onlyOwner() returns (bytes memory) {
    require(target.isContract(), 'call to non-contract');
    require(factory.isWhitelisted(target), 'Invalid target contract');
    return target.functionCall(callData);
  }

  function initialize(address _lob, address _trader) initializer external override{
    OrderBook = LimitOrderBook(_lob);
    factory = SmartWalletFactory(msg.sender);
    owner = _trader;
  }

  function executeMarketOrder(
    IAmm _asset,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage
  ) external override onlyOwner() whenNotPaused() {
    _handleOpenPositionWithApproval(_asset, _orderSize, _collateral, _leverage, _slippage);
  }

  function executeClosePosition(
    IAmm _asset,
    Decimal.decimal memory _slippage
  ) external override onlyOwner() whenNotPaused() {
    _handleClosePositionWithApproval(_asset, _slippage);
  }

  function pauseWallet() external onlyOwner() {
    _pause();
  }

  function unpauseWallet() external onlyOwner() {
    _unpause();
  }

  /*
   * @notice Will execute an order from the limit order book. Note that the only
   *  way to call this function is via the LimitOrderBook where you call execute().
   * @param order_id is the ID of the order to execute
   */
  function executeOrder(
    uint order_id
  ) external override whenNotPaused() {
    //Only the LimitOrderBook can call this function
    require(msg.sender == address(OrderBook), 'Only execute from the order book');
    //Get some of the parameters
    (,address _trader,
      LimitOrderBook.OrderType _orderType,
      ,bool _stillValid, uint _expiry) =
      OrderBook.getLimitOrderParams(order_id);
    //Make sure that the order belongs to this smart wallet
    require(factory.getSmartWallet(_trader) == address(this), 'Incorrect smart wallet');
    //Make sure that the order hasn't expired
    require(((_expiry == 0 ) || (block.timestamp<_expiry)), 'Order expired');
    //Make sure the order is still valid
    require(_stillValid, 'Order no longer valid');
    //Perform function depending on the type of order

    if(_orderType == LimitOrderBook.OrderType.LIMIT) {
        _executeLimitOrder(order_id);
    } else if(_orderType == LimitOrderBook.OrderType.STOPMARKET) {
        _executeStopOrder(order_id);
    } else if(_orderType == LimitOrderBook.OrderType.STOPLIMIT) {
        _executeStopLimitOrder(order_id);
    } else if (_orderType == LimitOrderBook.OrderType.TRAILINGSTOPMARKET) {
        _executeStopOrder(order_id);
    } else if (_orderType == LimitOrderBook.OrderType.TRAILINGSTOPLIMIT) {
        _executeStopLimitOrder(order_id);
    }
  }

  function minD(Decimal.decimal memory a, Decimal.decimal memory b) internal pure
  returns (Decimal.decimal memory){
    return (a.cmp(b) >= 1) ? b : a;
  }

  function _handleOpenPositionWithApproval(
    IAmm _asset,
    SignedDecimal.signedDecimal memory _orderSize,
    Decimal.decimal memory _collateral,
    Decimal.decimal memory _leverage,
    Decimal.decimal memory _slippage
  ) internal {
    //Get cost of placing order (fees)
    (Decimal.decimal memory toll, Decimal.decimal memory spread) = _asset
      .calcFee(_collateral.mulD(_leverage));
    Decimal.decimal memory totalCost = _collateral.addD(toll).addD(spread);

    IERC20 quoteAsset = _asset.quoteAsset();
    _approve(quoteAsset, CLEARINGHOUSE, totalCost);

    //Establish how much leverage will be needed for that order based on the
    //amount of collateral and the maximum leverage the user was happy with.
    bool _isLong = _orderSize.isNegative() ? false : true;

    Decimal.decimal memory _size = _orderSize.abs();
    Decimal.decimal memory _quote = (IAmm(_asset)
      .getOutputPrice(_isLong ? IAmm.Dir.REMOVE_FROM_AMM : IAmm.Dir.ADD_TO_AMM, _size));
    Decimal.decimal memory _offset = Decimal.decimal(1); //Need to add one wei for rounding
    _leverage = minD(_quote.divD(_collateral).addD(_offset),_leverage);

    IClearingHouse(CLEARINGHOUSE).openPosition(
      _asset,
      _isLong ? IClearingHouse.Side.BUY : IClearingHouse.Side.SELL,
      _collateral,
      _leverage,
      _slippage
      );
  }

  function _calcBaseAssetAmountLimit(
    Decimal.decimal memory _positionSize,
    bool _isLong,
    Decimal.decimal memory _slippage
  ) internal pure returns (Decimal.decimal memory){
    Decimal.decimal memory factor;
    require(_slippage.cmp(Decimal.one()) == -1, 'Slippage must be %');
    if (_isLong) {
      //base amount must be greater than base amount limit
      factor = Decimal.one().subD(_slippage);
    } else {
      //base amount must be less than base amount limit
      factor = Decimal.one().addD(_slippage);
    }
    return factor.mulD(_positionSize);
  }

  /*

    OPEN LONG
    BASE ASSET LIMIT = POSITION SIZE - SLIPPAGE

    OPEN SHORT
    BASE ASSET LIMIT = POSITION SIZE + SLIPPAGE

    CLOSE LONG
    QUOTE ASSET LIMIT = VALUE - SLIPPAGE

    CLOSE SHORT
    QUOTE ASSET LIMIT = VALUE + SLIPPAGE

  */

  function _calcQuoteAssetAmountLimit(
    IAmm _asset,
    Decimal.decimal memory _targetPrice,
    bool _isLong,
    Decimal.decimal memory _slippage
  ) internal view returns (Decimal.decimal memory){
    IClearingHouse.Position memory oldPosition = IClearingHouse(CLEARINGHOUSE)
      .getPosition(_asset, address(this));
    SignedDecimal.signedDecimal memory oldPositionSize = oldPosition.size;
    Decimal.decimal memory value = oldPositionSize.abs().mulD(_targetPrice);
    Decimal.decimal memory factor;
    require(_slippage.cmp(Decimal.one()) == -1, 'Slippage must be %');
    if (_isLong) {
      //quote amount must be less than quote amount limit
      factor = Decimal.one().subD(_slippage);
    } else {
      //quote amount must be greater than quote amount limit
      factor = Decimal.one().addD(_slippage);
    }
    return factor.mulD(value);
  }

  function _handleClosePositionWithApproval(
    IAmm _asset,
    Decimal.decimal memory _slippage
  ) internal {
    //Need to calculate trading fees to close position (no margin required)
    IClearingHouse.Position memory oldPosition = IClearingHouse(CLEARINGHOUSE)
      .getPosition(_asset, address(this));
    SignedDecimal.signedDecimal memory oldPositionSize = oldPosition.size;
    Decimal.decimal memory _quoteAsset = _asset.getOutputPrice(
      oldPositionSize.toInt() > 0 ? IAmm.Dir.ADD_TO_AMM : IAmm.Dir.REMOVE_FROM_AMM,
      oldPositionSize.abs()
      );
    (Decimal.decimal memory toll, Decimal.decimal memory spread) = _asset
      .calcFee(_quoteAsset);
    Decimal.decimal memory totalCost = toll.addD(spread);

    IERC20 quoteAsset = _asset.quoteAsset();
    _approve(quoteAsset, CLEARINGHOUSE, totalCost);

    IClearingHouse(CLEARINGHOUSE).closePosition(
      _asset,
      _slippage
      );
  }

  /*
   * @notice check what this order should do if it is reduceOnly
   *  To clarify, only reduceOnly orders should call this function:
   *    If it returns true, then the order should close the position rather than
   *    opening one.
   * @param _asset the AMM for the asset
   * @param _orderSize the size of the order (note: negative are SELL/SHORt)
   */
  function _shouldCloseReduceOnly(
    IAmm _asset,
    SignedDecimal.signedDecimal memory _orderSize
  ) internal view returns (bool) {
    //Get the size of the users current position
    IClearingHouse.Position memory _currentPosition = IClearingHouse(CLEARINGHOUSE)
      .getPosition(IAmm(_asset), address(this));
    SignedDecimal.signedDecimal memory _currentSize = _currentPosition.size;
    //If the user has no position for this asset, then cannot execute a reduceOnly order
    require(_currentSize.abs().toUint() != 0, "#reduceOnly: current size is 0");
    //If the direction of the order is opposite to the users current position
    if(_orderSize.isNegative() != _currentSize.isNegative()) {
      //User is long and wants to sell:
      if(_orderSize.isNegative()) {
        //The size of the order is large enough to open a reverse position,
        //therefore we should close it instead
        if(_orderSize.abs().cmp(_currentSize.abs()) == 1) {
          return true;
        }
      } else {
        //User is short and wants to buy:
        if(_currentSize.abs().cmp(_orderSize.abs()) == 1) {
          //The size of the order is large enough to open a reverse position,
          //therefore we should close it instead
          return true;
        }
      }
    } else {
      //User is trying to increase the size of their position
      revert('#reduceOnly: cannot increase size of position');
    }
  }

  /*
   * @notice internal position to execute limit order - note that you need to
   *  check that this is a limit order before calling this function
   */
  function _executeLimitOrder(
    uint order_id
  ) internal {
    //Get information of limit order
    (,Decimal.decimal memory _limitPrice,
      SignedDecimal.signedDecimal memory _orderSize,
      Decimal.decimal memory _collateral,
      Decimal.decimal memory _leverage,
      Decimal.decimal memory _slippage,,
      address _asset, bool _reduceOnly) = OrderBook.getLimitOrderPrices(order_id);

    //Check whether we need to close position or open position
    bool closePosition = false;
    if(_reduceOnly) {
      closePosition = _shouldCloseReduceOnly(IAmm(_asset), _orderSize);
    }

    //Establish whether long or short
    bool isLong = _orderSize.isNegative() ? false : true;
    //Get the current spot price of the asset
    Decimal.decimal memory _markPrice = IAmm(_asset).getSpotPrice();
    require(_markPrice.cmp(Decimal.zero()) >= 1, 'Error getting mark price');

    //Check whether price conditions have been met:
    //  LIMIT BUY: mark price < limit price
    //  LIMIT SELL: mark price > limit price
    require((_limitPrice.cmp(_markPrice)) == (isLong ? int128(1) : -1), 'Invalid limit order condition');

    if(closePosition) {
      Decimal.decimal memory quoteAssetLimit = _calcQuoteAssetAmountLimit(IAmm(_asset), _limitPrice, isLong, _slippage);
      _handleClosePositionWithApproval(IAmm(_asset), quoteAssetLimit);
    } else {
      //openPosition using the values calculated above
      Decimal.decimal memory baseAssetLimit = _calcBaseAssetAmountLimit(_orderSize.abs(), isLong, _slippage);
      _handleOpenPositionWithApproval(IAmm(_asset), _orderSize, _collateral, _leverage, baseAssetLimit);
    }

  }

  function _executeStopOrder(
    uint order_id
  ) internal {
    //Get information of stop order
    (Decimal.decimal memory _stopPrice,,
      SignedDecimal.signedDecimal memory _orderSize,
      Decimal.decimal memory _collateral,
      Decimal.decimal memory _leverage,,,
      address _asset, bool _reduceOnly) = OrderBook.getLimitOrderPrices(order_id);

    //Check whether we need to close position or open position
    bool closePosition = false;
    if(_reduceOnly) {
      closePosition = _shouldCloseReduceOnly(IAmm(_asset), _orderSize);
    }

    //Establish whether long or short
    bool isLong = _orderSize.isNegative() ? false : true;
    //Get the current spot price of the asset
    Decimal.decimal memory _markPrice = IAmm(_asset).getSpotPrice();
    require(_markPrice.cmp(Decimal.zero()) >= 1, 'Error getting mark price');
    //Check whether price conditions have been met:
    //  STOP BUY: mark price > stop price
    //  STOP SELL: mark price < stop price
    require((_markPrice.cmp(_stopPrice)) == (isLong ? int128(1) : -1), 'Invalid stop order conditions');

    //Strictly speaking, stop orders cannot have slippage as by definition they
    //will get executed at the next available price. Restricting them with slippage
    //will turn them into stop limit orders.
    if(closePosition) {
      _handleClosePositionWithApproval(IAmm(_asset), Decimal.decimal(0));
    } else {
      _handleOpenPositionWithApproval(IAmm(_asset), _orderSize, _collateral, _leverage, Decimal.decimal(0));
    }

  }

  function _executeStopLimitOrder(
    uint order_id
  ) internal {
    //Get information of stop limit order
    (Decimal.decimal memory _stopPrice,
      Decimal.decimal memory _limitPrice,
      SignedDecimal.signedDecimal memory _orderSize,
      Decimal.decimal memory _collateral,
      Decimal.decimal memory _leverage,
      Decimal.decimal memory _slippage,,
      address _asset, bool _reduceOnly) = OrderBook.getLimitOrderPrices(order_id);

    //Check whether we need to close position or open position
    bool closePosition = false;
    if(_reduceOnly) {
      closePosition = _shouldCloseReduceOnly(IAmm(_asset), _orderSize);
    }

    //Establish whether long or short
    bool isLong = _orderSize.isNegative() ? false : true;
    //Get the current spot price of the asset
    Decimal.decimal memory _markPrice = IAmm(_asset).getSpotPrice();
    require(_markPrice.cmp(Decimal.zero()) >= 1, 'Error getting mark price');
    //Check whether price conditions have been met:
    //  STOP LIMIT BUY: limit price > mark price > stop price
    //  STOP LIMIT SELL: limit price < mark price < stop price
    require((_limitPrice.cmp(_markPrice)) == (isLong ? int128(1) : -1) &&
      (_markPrice.cmp(_stopPrice)) == (isLong ? int128(1) : -1), 'Invalid stop-limit condition');
    if(closePosition) {
      Decimal.decimal memory quoteAssetLimit = _calcQuoteAssetAmountLimit(IAmm(_asset), _limitPrice, isLong, _slippage);
      _handleClosePositionWithApproval(IAmm(_asset), quoteAssetLimit);
    } else {
      //openPosition using the values calculated above
      Decimal.decimal memory baseAssetLimit = _calcBaseAssetAmountLimit(_orderSize.abs(), isLong, _slippage);
      _handleOpenPositionWithApproval(IAmm(_asset), _orderSize, _collateral, _leverage, baseAssetLimit);
    }
  }

  modifier onlyOwner() {
      require(owner == msg.sender, "Ownable: caller is not the owner");
      _;
  }

}

contract SmartWalletFactory is ISmartWalletFactory, Ownable{
  event Created(address indexed owner, address indexed smartWallet);

  mapping (address => address) public override getSmartWallet;
  mapping (address => bool) public isWhitelisted;

  address public LimitOrderBook;

  constructor(address _addr) public {
    LimitOrderBook = _addr;
  }

  /*
   * @notice Create and deploy a smart wallet for the user and stores the address
   */
  function spawn() external returns (address smartWallet) {
    require(getSmartWallet[msg.sender] == address(0), 'Already has smart wallet');

    bytes memory bytecode = type(SmartWallet).creationCode;
    bytes32 salt = keccak256(abi.encodePacked(msg.sender));
    assembly {
      smartWallet := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
    }

    emit Created(msg.sender, smartWallet);
    ISmartWallet(smartWallet).initialize(LimitOrderBook, msg.sender);
    getSmartWallet[msg.sender] = smartWallet;
  }

  function addToWhitelist(address _contract) external onlyOwner{
    isWhitelisted[_contract] = true;
  }

  function removeFromWhitelist(address _contract) external onlyOwner{
    isWhitelisted[_contract] = false;
  }

}
