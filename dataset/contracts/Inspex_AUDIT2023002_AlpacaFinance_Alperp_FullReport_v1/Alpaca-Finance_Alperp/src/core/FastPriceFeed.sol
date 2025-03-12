// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ISecondaryPriceFeed } from "../interfaces/ISecondaryPriceFeed.sol";
import { IMarketOrderRouter } from "../interfaces/IMarketOrderRouter.sol";
import { PoolOracle } from "../core/PoolOracle.sol";
import { Orderbook } from "../core/pool-diamond/limit-orders/Orderbook.sol";

/// @notice This contract will be deprecated after 0.3.1
contract FastPriceFeed is OwnableUpgradeable {
  // fit data in a uint256 slot to save gas costs
  struct PriceDataItem {
    uint160 refPrice; // Chainlink price
    uint32 refTime; // last updated at time
    uint32 cumulativeRefDelta; // cumulative Chainlink price delta
    uint32 cumulativeFastDelta; // cumulative fast price delta
  }
  struct LimitOrderKey {
    address primaryAccount;
    uint256 subAccountId;
    uint256 orderIndex;
  }

  uint256 public constant PRICE_PRECISION = 10**30;

  uint256 public constant CUMULATIVE_DELTA_PRECISION = 10 * 1000 * 1000;

  uint256 public constant MAX_REF_PRICE = type(uint160).max;
  uint256 public constant MAX_CUMULATIVE_REF_DELTA = type(uint32).max;
  uint256 public constant MAX_CUMULATIVE_FAST_DELTA = type(uint32).max;

  // type(uint256).max is 256 bits of 1s
  // shift the 1s by (256 - 32) to get (256 - 32) 0s followed by 32 1s
  uint256 public constant BITMASK_32 = type(uint256).max >> (256 - 32);

  uint256 public constant BASIS_POINTS_DIVISOR = 10000;

  uint256 public constant MAX_PRICE_DURATION = 30 minutes;

  bool public isInitialized;
  bool public isSpreadEnabled;

  address public poolOracle;

  address public tokenManager;

  address public positionRouter; // market order
  address public orderbook; // limit/trigger order

  uint256 public lastUpdatedAt;
  uint256 public lastUpdatedBlock;

  uint256 public priceDuration;
  uint256 public maxPriceUpdateDelay;
  uint256 public spreadBasisPointsIfInactive;
  uint256 public spreadBasisPointsIfChainError;
  uint256 public minBlockInterval;
  uint256 public maxTimeDeviation;

  uint256 public priceDataInterval;

  // allowed deviation from primary price
  uint256 public maxDeviationBasisPoints;

  uint256 public minAuthorizations;
  uint256 public disableFastPriceVoteCount;

  mapping(address => bool) public isUpdater;

  mapping(address => uint256) public prices;
  mapping(address => PriceDataItem) public priceData;
  mapping(address => uint256) public maxCumulativeDeltaDiffs;

  mapping(address => bool) public isSigner;
  mapping(address => bool) public disableFastPriceVotes;

  // array of tokens used in setCompactedPrices, saves L1 calldata gas costs
  address[] public tokens;
  // array of tokenPrecisions used in setCompactedPrices, saves L1 calldata gas costs
  // if the token price will be sent with 3 decimals, then tokenPrecision for that token
  // should be 10 ** 3
  uint256[] public tokenPrecisions;

  event DisableFastPrice(address signer);
  event EnableFastPrice(address signer);
  event PriceData(
    address indexed token,
    uint256 refPrice,
    uint256 fastPrice,
    uint256 cumulativeRefDelta,
    uint256 cumulativeFastDelta,
    bytes32 indexed checksum
  );
  event MaxCumulativeDeltaDiffExceeded(
    address token,
    uint256 refPrice,
    uint256 fastPrice,
    uint256 cumulativeRefDelta,
    uint256 cumulativeFastDelta
  );

  modifier onlySigner() {
    require(isSigner[msg.sender], "FastPriceFeed: forbidden");
    _;
  }

  modifier onlyUpdater() {
    require(isUpdater[msg.sender], "FastPriceFeed: forbidden");
    _;
  }

  modifier onlyTokenManager() {
    require(msg.sender == tokenManager, "FastPriceFeed: forbidden");
    _;
  }

  function initialize(
    uint256 _priceDuration,
    uint256 _maxPriceUpdateDelay,
    uint256 _minBlockInterval,
    uint256 _maxDeviationBasisPoints,
    address _tokenManager,
    address _positionRouter,
    address _orderbook
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    require(
      _priceDuration <= MAX_PRICE_DURATION,
      "FastPriceFeed: invalid _priceDuration"
    );
    priceDuration = _priceDuration;
    maxPriceUpdateDelay = _maxPriceUpdateDelay;
    minBlockInterval = _minBlockInterval;
    maxDeviationBasisPoints = _maxDeviationBasisPoints;
    tokenManager = _tokenManager;
    positionRouter = _positionRouter;
    orderbook = _orderbook;

    isSpreadEnabled = false;
    disableFastPriceVoteCount = 0;
  }

  function init(
    uint256 _minAuthorizations,
    address[] memory _signers,
    address[] memory _updaters
  ) public onlyOwner {
    require(!isInitialized, "FastPriceFeed: already initialized");
    isInitialized = true;

    minAuthorizations = _minAuthorizations;

    for (uint256 i = 0; i < _signers.length; i++) {
      address signer = _signers[i];
      isSigner[signer] = true;
    }

    for (uint256 i = 0; i < _updaters.length; i++) {
      address updater = _updaters[i];
      isUpdater[updater] = true;
    }
  }

  function setSigner(address _account, bool _isActive) external onlyOwner {
    isSigner[_account] = _isActive;
  }

  function setUpdater(address _account, bool _isActive) external onlyOwner {
    isUpdater[_account] = _isActive;
  }

  function setPoolOracle(address _poolOracle) external onlyOwner {
    poolOracle = _poolOracle;
  }

  function setMaxTimeDeviation(uint256 _maxTimeDeviation) external onlyOwner {
    maxTimeDeviation = _maxTimeDeviation;
  }

  function setPriceDuration(uint256 _priceDuration) external onlyOwner {
    require(
      _priceDuration <= MAX_PRICE_DURATION,
      "FastPriceFeed: invalid _priceDuration"
    );
    priceDuration = _priceDuration;
  }

  function setMaxPriceUpdateDelay(uint256 _maxPriceUpdateDelay)
    external
    onlyOwner
  {
    maxPriceUpdateDelay = _maxPriceUpdateDelay;
  }

  function setSpreadBasisPointsIfInactive(uint256 _spreadBasisPointsIfInactive)
    external
    onlyOwner
  {
    spreadBasisPointsIfInactive = _spreadBasisPointsIfInactive;
  }

  function setSpreadBasisPointsIfChainError(
    uint256 _spreadBasisPointsIfChainError
  ) external onlyOwner {
    spreadBasisPointsIfChainError = _spreadBasisPointsIfChainError;
  }

  function setMinBlockInterval(uint256 _minBlockInterval) external onlyOwner {
    minBlockInterval = _minBlockInterval;
  }

  function setIsSpreadEnabled(bool _isSpreadEnabled) external onlyOwner {
    isSpreadEnabled = _isSpreadEnabled;
  }

  function setLastUpdatedAt(uint256 _lastUpdatedAt) external onlyOwner {
    lastUpdatedAt = _lastUpdatedAt;
  }

  function setTokenManager(address _tokenManager) external onlyTokenManager {
    tokenManager = _tokenManager;
  }

  function setMaxDeviationBasisPoints(uint256 _maxDeviationBasisPoints)
    external
    onlyTokenManager
  {
    maxDeviationBasisPoints = _maxDeviationBasisPoints;
  }

  function setMaxCumulativeDeltaDiffs(
    address[] memory _tokens,
    uint256[] memory _maxCumulativeDeltaDiffs
  ) external onlyTokenManager {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address token = _tokens[i];
      maxCumulativeDeltaDiffs[token] = _maxCumulativeDeltaDiffs[i];
    }
  }

  function setPriceDataInterval(uint256 _priceDataInterval)
    external
    onlyTokenManager
  {
    priceDataInterval = _priceDataInterval;
  }

  function setMinAuthorizations(uint256 _minAuthorizations)
    external
    onlyTokenManager
  {
    minAuthorizations = _minAuthorizations;
  }

  function setTokens(
    address[] memory _tokens,
    uint256[] memory _tokenPrecisions
  ) external onlyOwner {
    require(
      _tokens.length == _tokenPrecisions.length,
      "FastPriceFeed: invalid lengths"
    );
    tokens = _tokens;
    tokenPrecisions = _tokenPrecisions;
  }

  function setConfigs(
    address[] memory _tokens,
    uint256[] memory _tokenPrecisions,
    uint256 _minAuthorizations,
    uint256 _priceDataInterval,
    uint256[] memory _maxCumulativeDeltaDiffs,
    uint256 _maxTimeDeviation,
    uint256 _spreadBasisPointsIfChainError,
    uint256 _spreadBasisPointsIfInactive
  ) external onlyOwner {
    require(
      _tokens.length == _tokenPrecisions.length,
      "FastPriceFeed: invalid lengths"
    );
    tokens = _tokens;
    tokenPrecisions = _tokenPrecisions;

    minAuthorizations = _minAuthorizations;
    priceDataInterval = _priceDataInterval;

    for (uint256 i = 0; i < _tokens.length; i++) {
      address token = _tokens[i];
      maxCumulativeDeltaDiffs[token] = _maxCumulativeDeltaDiffs[i];
    }

    maxTimeDeviation = _maxTimeDeviation;
    spreadBasisPointsIfChainError = _spreadBasisPointsIfChainError;
    spreadBasisPointsIfInactive = _spreadBasisPointsIfInactive;
  }

  function setPrices(
    address[] memory _tokens,
    uint256[] memory _prices,
    uint256 _timestamp,
    bytes32 _checksum
  ) external onlyUpdater {
    bool shouldUpdate = _setLastUpdatedValues(_timestamp);

    if (shouldUpdate) {
      address _poolOracle = poolOracle;

      for (uint256 i = 0; i < _tokens.length; i++) {
        address token = _tokens[i];
        _setPrice(token, _prices[i], _poolOracle, _checksum);
      }
    }
  }

  function setCompactedPrices(
    uint256[] memory _priceBitArray,
    uint256 _timestamp,
    bytes32 _checksum
  ) external onlyUpdater {
    bool shouldUpdate = _setLastUpdatedValues(_timestamp);

    if (shouldUpdate) {
      address _poolOracle = poolOracle;

      for (uint256 i = 0; i < _priceBitArray.length; i++) {
        uint256 priceBits = _priceBitArray[i];

        for (uint256 j = 0; j < 8; j++) {
          uint256 index = i * 8 + j;
          if (index >= tokens.length) {
            return;
          }

          uint256 startBit = 32 * j;
          uint256 price = (priceBits >> startBit) & BITMASK_32;

          address token = tokens[i * 8 + j];
          uint256 tokenPrecision = tokenPrecisions[i * 8 + j];
          uint256 adjustedPrice = (price * PRICE_PRECISION) / tokenPrecision;

          _setPrice(token, adjustedPrice, _poolOracle, _checksum);
        }
      }
    }
  }

  function setPricesWithBits(
    uint256 _priceBits,
    uint256 _timestamp,
    bytes32 _checksum
  ) external onlyUpdater {
    _setPricesWithBits(_priceBits, _timestamp, _checksum);
  }

  function setPricesWithBitsAndExecute(
    uint256 _priceBits,
    uint256 _timestamp,
    uint256 _endIndexForIncreasePositions,
    uint256 _endIndexForDecreasePositions,
    uint256 _endIndexForSwapOrders,
    uint256 _maxIncreasePositions,
    uint256 _maxDecreasePositions,
    uint256 _maxSwapOrders,
    address payable _feeReceiver,
    bytes32 _checksum
  ) external onlyUpdater {
    _setPricesWithBits(_priceBits, _timestamp, _checksum);

    IMarketOrderRouter _positionRouter = IMarketOrderRouter(positionRouter);
    uint256 maxEndIndexForIncrease = _positionRouter
      .increasePositionRequestKeysStart() + _maxIncreasePositions;
    uint256 maxEndIndexForDecrease = _positionRouter
      .decreasePositionRequestKeysStart() + _maxDecreasePositions;
    uint256 maxEndIndexForSwap = _positionRouter.swapOrderRequestKeysStart() +
      _maxSwapOrders;

    if (_endIndexForIncreasePositions > maxEndIndexForIncrease) {
      _endIndexForIncreasePositions = maxEndIndexForIncrease;
    }

    if (_endIndexForDecreasePositions > maxEndIndexForDecrease) {
      _endIndexForDecreasePositions = maxEndIndexForDecrease;
    }

    if (_endIndexForSwapOrders > maxEndIndexForSwap) {
      _endIndexForSwapOrders = maxEndIndexForSwap;
    }

    _positionRouter.executeIncreasePositions(
      _endIndexForIncreasePositions,
      _feeReceiver
    );
    _positionRouter.executeDecreasePositions(
      _endIndexForDecreasePositions,
      _feeReceiver
    );
    _positionRouter.executeSwapOrders(_endIndexForSwapOrders, _feeReceiver);
  }

  function setPricesWithBitsAndExecute(
    uint256 _priceBits,
    uint256 _timestamp,
    LimitOrderKey[] memory _increaseOrders,
    LimitOrderKey[] memory _decreaseOrders,
    LimitOrderKey[] memory _swapOrders,
    address payable _feeReceiver,
    bytes32 _checksum,
    bool _revertOnError
  ) external onlyUpdater {
    _setPricesWithBits(_priceBits, _timestamp, _checksum);

    Orderbook _orderbook = Orderbook(payable(orderbook));
    for (uint256 i = 0; i < _increaseOrders.length; ) {
      if (!_revertOnError) {
        try
          _orderbook.executeIncreaseOrder(
            _increaseOrders[i].primaryAccount,
            _increaseOrders[i].subAccountId,
            _increaseOrders[i].orderIndex,
            payable(_feeReceiver)
          )
        {} catch {}
      } else {
        _orderbook.executeIncreaseOrder(
          _increaseOrders[i].primaryAccount,
          _increaseOrders[i].subAccountId,
          _increaseOrders[i].orderIndex,
          payable(_feeReceiver)
        );
      }

      unchecked {
        i++;
      }
    }

    for (uint256 i = 0; i < _decreaseOrders.length; ) {
      if (!_revertOnError) {
        try
          _orderbook.executeDecreaseOrder(
            _decreaseOrders[i].primaryAccount,
            _decreaseOrders[i].subAccountId,
            _decreaseOrders[i].orderIndex,
            payable(_feeReceiver)
          )
        {} catch {}
      } else {
        _orderbook.executeDecreaseOrder(
          _decreaseOrders[i].primaryAccount,
          _decreaseOrders[i].subAccountId,
          _decreaseOrders[i].orderIndex,
          payable(_feeReceiver)
        );
      }

      unchecked {
        i++;
      }
    }

    for (uint256 i = 0; i < _swapOrders.length; ) {
      if (!_revertOnError) {
        try
          _orderbook.executeSwapOrder(
            _decreaseOrders[i].primaryAccount,
            _decreaseOrders[i].orderIndex,
            payable(_feeReceiver)
          )
        {} catch {}
      } else {
        _orderbook.executeSwapOrder(
          _decreaseOrders[i].primaryAccount,
          _decreaseOrders[i].orderIndex,
          payable(_feeReceiver)
        );
      }

      unchecked {
        i++;
      }
    }
  }

  function disableFastPrice() external onlySigner {
    require(!disableFastPriceVotes[msg.sender], "FastPriceFeed: already voted");
    disableFastPriceVotes[msg.sender] = true;
    disableFastPriceVoteCount = disableFastPriceVoteCount + 1;

    emit DisableFastPrice(msg.sender);
  }

  function enableFastPrice() external onlySigner {
    require(
      disableFastPriceVotes[msg.sender],
      "FastPriceFeed: already enabled"
    );
    disableFastPriceVotes[msg.sender] = false;
    disableFastPriceVoteCount = disableFastPriceVoteCount - 1;

    emit EnableFastPrice(msg.sender);
  }

  // under regular operation, the fastPrice (prices[token]) is returned and there is no spread returned from this function,
  // though PoolOracle might apply its own spread
  //
  // if the fastPrice has not been updated within priceDuration then it is ignored and only _refPrice with a spread is used (spread: spreadBasisPointsIfInactive)
  // in case the fastPrice has not been updated for maxPriceUpdateDelay then the _refPrice with a larger spread is used (spread: spreadBasisPointsIfChainError)
  //
  // there will be a spread from the _refPrice to the fastPrice in the following cases:
  // - in case isSpreadEnabled is set to true
  // - in case the maxDeviationBasisPoints between _refPrice and fastPrice is exceeded
  // - in case watchers flag an issue
  // - in case the cumulativeFastDelta exceeds the cumulativeRefDelta by the maxCumulativeDeltaDiff
  function getPrice(
    address _token,
    uint256 _refPrice,
    bool _maximise
  ) external view returns (uint256) {
    if (block.timestamp > lastUpdatedAt + maxPriceUpdateDelay) {
      if (_maximise) {
        return
          (_refPrice * (BASIS_POINTS_DIVISOR + spreadBasisPointsIfChainError)) /
          (BASIS_POINTS_DIVISOR);
      }

      return
        (_refPrice * (BASIS_POINTS_DIVISOR - spreadBasisPointsIfChainError)) /
        (BASIS_POINTS_DIVISOR);
    }

    if (block.timestamp > lastUpdatedAt + priceDuration) {
      if (_maximise) {
        return
          (_refPrice * (BASIS_POINTS_DIVISOR + spreadBasisPointsIfInactive)) /
          (BASIS_POINTS_DIVISOR);
      }

      return
        (_refPrice * (BASIS_POINTS_DIVISOR - (spreadBasisPointsIfInactive))) /
        (BASIS_POINTS_DIVISOR);
    }

    uint256 fastPrice = prices[_token];
    if (fastPrice == 0) {
      return _refPrice;
    }

    uint256 diffBasisPoints = _refPrice > fastPrice
      ? _refPrice - (fastPrice)
      : fastPrice - (_refPrice);
    diffBasisPoints = (diffBasisPoints * (BASIS_POINTS_DIVISOR)) / (_refPrice);

    // create a spread between the _refPrice and the fastPrice if the maxDeviationBasisPoints is exceeded
    // or if watchers have flagged an issue with the fast price
    bool hasSpread = !favorFastPrice(_token) ||
      diffBasisPoints > maxDeviationBasisPoints;

    if (hasSpread) {
      return _refPrice;
    }

    return fastPrice;
  }

  function favorFastPrice(address _token) public view returns (bool) {
    if (isSpreadEnabled) {
      return false;
    }

    if (disableFastPriceVoteCount >= minAuthorizations) {
      // force a spread if watchers have flagged an issue with the fast price
      return false;
    }

    (
      ,
      ,
      /* uint256 prevRefPrice */
      /* uint256 refTime */
      uint256 cumulativeRefDelta,
      uint256 cumulativeFastDelta
    ) = getPriceData(_token);
    if (
      cumulativeFastDelta > cumulativeRefDelta &&
      cumulativeFastDelta - cumulativeRefDelta > maxCumulativeDeltaDiffs[_token]
    ) {
      // force a spread if the cumulative delta for the fast price feed exceeds the cumulative delta
      // for the Chainlink price feed by the maxCumulativeDeltaDiff allowed
      return false;
    }

    return true;
  }

  function getPriceData(address _token)
    public
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    PriceDataItem memory data = priceData[_token];
    return (
      uint256(data.refPrice),
      uint256(data.refTime),
      uint256(data.cumulativeRefDelta),
      uint256(data.cumulativeFastDelta)
    );
  }

  function _setPricesWithBits(
    uint256 _priceBits,
    uint256 _timestamp,
    bytes32 _checksum
  ) private {
    bool shouldUpdate = _setLastUpdatedValues(_timestamp);
    if (shouldUpdate) {
      address _poolOracle = poolOracle;

      for (uint256 j = 0; j < 8; j++) {
        uint256 index = j;
        if (index >= tokens.length) {
          return;
        }

        uint256 startBit = 32 * j;
        uint256 price = (_priceBits >> startBit) & BITMASK_32;

        address token = tokens[j];
        uint256 tokenPrecision = tokenPrecisions[j];
        uint256 adjustedPrice = (price * PRICE_PRECISION) / tokenPrecision;

        _setPrice(token, adjustedPrice, _poolOracle, _checksum);
      }
    }
  }

  function _setPrice(
    address _token,
    uint256 _price,
    address _poolOracle,
    bytes32 _checksum
  ) private {
    if (_poolOracle != address(0)) {
      uint256 refPrice = PoolOracle(_poolOracle).getLatestPrimaryPrice(_token);
      uint256 fastPrice = prices[_token];

      (
        uint256 prevRefPrice,
        uint256 refTime,
        uint256 cumulativeRefDelta,
        uint256 cumulativeFastDelta
      ) = getPriceData(_token);

      if (prevRefPrice > 0) {
        uint256 refDeltaAmount = refPrice > prevRefPrice
          ? refPrice - prevRefPrice
          : prevRefPrice - refPrice;
        uint256 fastDeltaAmount = fastPrice > _price
          ? fastPrice - _price
          : _price - fastPrice;

        // reset cumulative delta values if it is a new time window
        if (
          refTime / priceDataInterval != block.timestamp / priceDataInterval
        ) {
          cumulativeRefDelta = 0;
          cumulativeFastDelta = 0;
        }

        if (prevRefPrice > 0) {
          cumulativeRefDelta =
            cumulativeRefDelta +
            ((refDeltaAmount * CUMULATIVE_DELTA_PRECISION) / prevRefPrice);
        }
        if (fastPrice > 0) {
          cumulativeFastDelta =
            cumulativeFastDelta +
            ((fastDeltaAmount * CUMULATIVE_DELTA_PRECISION) / fastPrice);
        }
      }

      if (
        cumulativeFastDelta > cumulativeRefDelta &&
        cumulativeFastDelta - cumulativeRefDelta >
        maxCumulativeDeltaDiffs[_token]
      ) {
        emit MaxCumulativeDeltaDiffExceeded(
          _token,
          refPrice,
          fastPrice,
          cumulativeRefDelta,
          cumulativeFastDelta
        );
      }

      _setPriceData(_token, refPrice, cumulativeRefDelta, cumulativeFastDelta);
      emit PriceData(
        _token,
        refPrice,
        fastPrice,
        cumulativeRefDelta,
        cumulativeFastDelta,
        _checksum
      );
    }

    prices[_token] = _price;
  }

  function _setPriceData(
    address _token,
    uint256 _refPrice,
    uint256 _cumulativeRefDelta,
    uint256 _cumulativeFastDelta
  ) private {
    require(_refPrice < MAX_REF_PRICE, "FastPriceFeed: invalid refPrice");
    // skip validation of block.timestamp, it should only be out of range after the year 2100
    require(
      _cumulativeRefDelta < MAX_CUMULATIVE_REF_DELTA,
      "FastPriceFeed: invalid cumulativeRefDelta"
    );
    require(
      _cumulativeFastDelta < MAX_CUMULATIVE_FAST_DELTA,
      "FastPriceFeed: invalid cumulativeFastDelta"
    );

    priceData[_token] = PriceDataItem(
      uint160(_refPrice),
      uint32(block.timestamp),
      uint32(_cumulativeRefDelta),
      uint32(_cumulativeFastDelta)
    );
  }

  function _setLastUpdatedValues(uint256 _timestamp) private returns (bool) {
    if (minBlockInterval > 0) {
      require(
        block.number - lastUpdatedBlock >= minBlockInterval,
        "FastPriceFeed: minBlockInterval not yet passed"
      );
    }

    uint256 _maxTimeDeviation = maxTimeDeviation;
    require(
      _timestamp > block.timestamp - _maxTimeDeviation,
      "FastPriceFeed: _timestamp below allowed range"
    );
    require(
      _timestamp < block.timestamp + _maxTimeDeviation,
      "FastPriceFeed: _timestamp exceeds allowed range"
    );

    // do not update prices if _timestamp is before the current lastUpdatedAt value
    if (_timestamp < lastUpdatedAt) {
      return false;
    }

    lastUpdatedAt = _timestamp;
    lastUpdatedBlock = block.number;

    return true;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  receive() external payable {}
}
