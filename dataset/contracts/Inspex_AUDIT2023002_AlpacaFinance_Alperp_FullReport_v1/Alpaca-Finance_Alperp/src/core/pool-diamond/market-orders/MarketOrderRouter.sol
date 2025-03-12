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

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IWNative } from "../../../interfaces/IWNative.sol";

import { IWNativeRelayer } from "../../../interfaces/IWNativeRelayer.sol";
import { IPoolOracle } from "../../../interfaces/IPoolOracle.sol";
import { GetterFacetInterface } from "../interfaces/GetterFacetInterface.sol";
import { LiquidityFacetInterface } from "../interfaces/LiquidityFacetInterface.sol";
import { PerpTradeFacetInterface } from "../interfaces/PerpTradeFacetInterface.sol";
import { LibPoolConfigV1 } from "../libraries/LibPoolConfigV1.sol";

/// @notice This contract will be deprecated after 0.3.1
contract MarketOrderRouter is ReentrancyGuardUpgradeable, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using AddressUpgradeable for address payable;

  uint256 public constant BASIS_POINTS_DIVISOR = 10000;

  struct IncreasePositionRequest {
    address account;
    uint256 subAccountId;
    address[] path;
    address indexToken;
    uint256 amountIn;
    uint256 minOut;
    uint256 sizeDelta;
    bool isLong;
    uint256 acceptablePrice;
    uint256 executionFee;
    uint256 blockNumber;
    uint256 blockTime;
    bool hasCollateralInETH;
  }

  struct DecreasePositionRequest {
    address account;
    uint256 subAccountId;
    address[] path;
    address indexToken;
    uint256 collateralDelta;
    uint256 sizeDelta;
    bool isLong;
    address receiver;
    uint256 acceptablePrice;
    uint256 minOut;
    uint256 executionFee;
    uint256 blockNumber;
    uint256 blockTime;
    bool withdrawETH;
  }

  struct SwapOrderRequest {
    address account;
    address[] path;
    uint256 amountIn;
    uint256 minOut;
    bool shouldUnwrap;
    uint256 executionFee;
    uint256 blockNumber;
    uint256 blockTime;
  }

  address public admin;
  address public pool;
  address public poolOracle;
  address public weth;

  // to prevent using the deposit and withdrawal of collateral as a zero fee swap,
  // there is a small depositFeeBps charged if a collateral deposit results in the decrease
  // of leverage for an existing position
  // increasePositionBufferBps allows for a small amount of decrease of leverage
  uint256 public depositFeeBps;
  uint256 public increasePositionBufferBps;

  mapping(address => uint256) public feeReserves;

  uint256 public minExecutionFee;

  uint256 public minBlockDelayKeeper;
  uint256 public minTimeDelayPublic;
  uint256 public maxTimeDelay;

  bool public isLeverageEnabled;

  bytes32[] public increasePositionRequestKeys;
  bytes32[] public decreasePositionRequestKeys;
  bytes32[] public swapOrderRequestKeys;

  uint256 public increasePositionRequestKeysStart;
  uint256 public decreasePositionRequestKeysStart;
  uint256 public swapOrderRequestKeysStart;

  address public wnativeRelayer;

  mapping(address => bool) public isPositionKeeper;

  mapping(address => uint256) public increasePositionsIndex;
  mapping(bytes32 => IncreasePositionRequest) public increasePositionRequests;
  mapping(address => uint256) public decreasePositionsIndex;
  mapping(bytes32 => DecreasePositionRequest) public decreasePositionRequests;
  mapping(address => uint256) public swapOrdersIndex;
  mapping(bytes32 => SwapOrderRequest) public swapOrderRequests;

  event SetDepositFee(uint256 depositFeeBps);
  event SetIncreasePositionBufferBps(uint256 increasePositionBufferBps);
  event SetAdmin(address admin);
  event WithdrawFees(address token, address receiver, uint256 amount);
  event IncreasePosition(
    address account,
    uint256 subAccountId,
    uint256 sizeDelta,
    uint256 marginFeeBasisPoints
  );
  event DecreasePosition(
    address account,
    uint256 subAccountId,
    uint256 sizeDelta,
    uint256 marginFeeBasisPoints
  );
  event CreateIncreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 amountIn,
    uint256 minOut,
    uint256 sizeDelta,
    bool isLong,
    uint256 acceptablePrice,
    uint256 executionFee,
    uint256 index,
    uint256 queueIndex,
    uint256 gasPrice
  );
  event ExecuteIncreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 amountIn,
    uint256 minOut,
    uint256 sizeDelta,
    bool isLong,
    uint256 blockGap,
    uint256 timeGap,
    uint256 queueIndex,
    uint256 markPrice
  );
  event CancelIncreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 amountIn,
    uint256 minOut,
    uint256 sizeDelta,
    bool isLong,
    uint256 blockGap,
    uint256 timeGap,
    uint256 index
  );
  event CreateDecreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    address receiver,
    uint256 acceptablePrice,
    uint256 minOut,
    uint256 executionFee,
    uint256 index,
    uint256 queueIndex
  );
  event ExecuteDecreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    uint256 blockGap,
    uint256 timeGap,
    uint256 queueIndex,
    uint256 markPrice
  );
  event CancelDecreasePosition(
    address indexed account,
    uint256 subAccountId,
    address[] path,
    address indexToken,
    uint256 collateralDelta,
    uint256 sizeDelta,
    bool isLong,
    uint256 blockGap,
    uint256 timeGap,
    uint256 index
  );
  event CreateSwapOrder(
    address account,
    address[] path,
    uint256 amountIn,
    uint256 minOut,
    bool shouldUnwrap,
    uint256 executionFee,
    uint256 index,
    uint256 queueIndex
  );
  event ExecuteSwapOrder(
    address account,
    address[] path,
    uint256 amountIn,
    uint256 minOut,
    bool shouldUnwrap,
    uint256 executionFee,
    uint256 amountOut,
    uint256 blockGap,
    uint256 timeGap,
    uint256 queueIndex
  );
  event CancelSwapOrder(
    address account,
    address[] path,
    uint256 amountIn,
    uint256 minOut,
    bool shouldUnwrap,
    uint256 executionFee,
    uint256 blockGap,
    uint256 timeGap,
    uint256 queueIndex
  );
  event SetPositionKeeper(address indexed account, bool isActive);
  event SetMinExecutionFee(uint256 minExecutionFee);
  event SetIsLeverageEnabled(bool isLeverageEnabled);
  event SetDelayValues(
    uint256 minBlockDelayKeeper,
    uint256 minTimeDelayPublic,
    uint256 maxTimeDelay
  );
  event SetRequestKeysStartValues(
    uint256 increasePositionRequestKeysStart,
    uint256 decreasePositionRequestKeysStart,
    uint256 swapOrderRequestKeysStart
  );
  event CollectFee(
    address indexed token,
    uint256 feeAmount,
    uint256 feeReserve
  );
  event SetPoolOracle(address indexed poolOracle);

  error InsufficientExecutionFee();
  error IncorrectValueTransferred();
  error InvalidPathLength();
  error InvalidPath();
  error OnlyAdmin();
  error OnlyPositionKeeper();
  error InvalidPriceForExecution();
  error InsufficientAmountOut();
  error Expired();
  error Forbidden();
  error MaxGlobalLongSizesExceeded();
  error MaxGlobalShortSizesExceeded();
  error TooEarly();
  error InvalidAmountIn();
  error OnlyNativeShouldWrap();
  error InvalidSender();

  modifier onlyAdmin() {
    if (msg.sender != admin) revert OnlyAdmin();
    _;
  }

  modifier onlyPositionKeeper() {
    if (!isPositionKeeper[msg.sender]) revert OnlyPositionKeeper();
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _pool,
    address _poolOracle,
    address _wnativeRelayer,
    address _weth,
    uint256 _depositFeeBps,
    uint256 _minExecutionFee
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    pool = _pool;
    poolOracle = _poolOracle;
    wnativeRelayer = _wnativeRelayer;
    weth = _weth;
    depositFeeBps = _depositFeeBps;
    minExecutionFee = _minExecutionFee;

    increasePositionBufferBps = 100;
    isLeverageEnabled = true;
  }

  function setAdmin(address _admin) external onlyOwner {
    admin = _admin;
    emit SetAdmin(_admin);
  }

  function setDepositFee(uint256 _depositFeeBps) external onlyAdmin {
    depositFeeBps = _depositFeeBps;
    emit SetDepositFee(_depositFeeBps);
  }

  function setPoolOracle(address _poolOracle) external onlyAdmin {
    poolOracle = _poolOracle;
    emit SetPoolOracle(_poolOracle);
  }

  function setIncreasePositionBufferBps(uint256 _increasePositionBufferBps)
    external
    onlyAdmin
  {
    increasePositionBufferBps = _increasePositionBufferBps;
    emit SetIncreasePositionBufferBps(_increasePositionBufferBps);
  }

  function withdrawFees(address _token, address _receiver) external onlyAdmin {
    uint256 amount = feeReserves[_token];
    if (amount == 0) {
      return;
    }

    feeReserves[_token] = 0;
    IERC20Upgradeable(_token).safeTransfer(_receiver, amount);

    emit WithdrawFees(_token, _receiver, amount);
  }

  function approve(
    address _token,
    address _spender,
    uint256 _amount
  ) external onlyOwner {
    IERC20Upgradeable(_token).approve(_spender, _amount);
  }

  function sendValue(address payable _receiver, uint256 _amount)
    external
    onlyOwner
  {
    _receiver.sendValue(_amount);
  }

  function setPositionKeeper(address _account, bool _isActive)
    external
    onlyAdmin
  {
    isPositionKeeper[_account] = _isActive;
    emit SetPositionKeeper(_account, _isActive);
  }

  function setMinExecutionFee(uint256 _minExecutionFee) external onlyAdmin {
    minExecutionFee = _minExecutionFee;
    emit SetMinExecutionFee(_minExecutionFee);
  }

  function setIsLeverageEnabled(bool _isLeverageEnabled) external onlyAdmin {
    isLeverageEnabled = _isLeverageEnabled;
    emit SetIsLeverageEnabled(_isLeverageEnabled);
  }

  function setDelayValues(
    uint256 _minBlockDelayKeeper,
    uint256 _minTimeDelayPublic,
    uint256 _maxTimeDelay
  ) external onlyAdmin {
    minBlockDelayKeeper = _minBlockDelayKeeper;
    minTimeDelayPublic = _minTimeDelayPublic;
    maxTimeDelay = _maxTimeDelay;
    emit SetDelayValues(
      _minBlockDelayKeeper,
      _minTimeDelayPublic,
      _maxTimeDelay
    );
  }

  function setRequestKeysStartValues(
    uint256 _increasePositionRequestKeysStart,
    uint256 _decreasePositionRequestKeysStart,
    uint256 _swapOrderRequestKeysStart
  ) external onlyAdmin {
    increasePositionRequestKeysStart = _increasePositionRequestKeysStart;
    decreasePositionRequestKeysStart = _decreasePositionRequestKeysStart;
    swapOrderRequestKeysStart = _swapOrderRequestKeysStart;

    emit SetRequestKeysStartValues(
      _increasePositionRequestKeysStart,
      _decreasePositionRequestKeysStart,
      _swapOrderRequestKeysStart
    );
  }

  function executeIncreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external onlyPositionKeeper {
    uint256 index = increasePositionRequestKeysStart;
    uint256 length = increasePositionRequestKeys.length;

    if (index >= length) {
      return;
    }

    if (_endIndex > length) {
      _endIndex = length;
    }

    while (index < _endIndex) {
      bytes32 key = increasePositionRequestKeys[index];

      // if the request was executed then delete the key from the array
      // if the request was not executed then break from the loop, this can happen if the
      // minimum number of blocks has not yet passed
      // an error could be thrown if the request is too old or if the slippage is
      // higher than what the user specified, or if there is insufficient liquidity for the position
      // in case an error was thrown, cancel the request
      try
        this.executeIncreasePosition(key, _executionFeeReceiver, index)
      returns (bool _wasExecuted) {
        if (!_wasExecuted) {
          break;
        }
      } catch {
        // wrap this call in a try catch to prevent invalid cancels from blocking the loop
        try
          this.cancelIncreasePosition(key, _executionFeeReceiver, index)
        returns (bool _wasCancelled) {
          if (!_wasCancelled) {
            break;
          }
        } catch {}
      }

      delete increasePositionRequestKeys[index];
      index++;
    }

    increasePositionRequestKeysStart = index;
  }

  function executeDecreasePositions(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external onlyPositionKeeper {
    uint256 index = decreasePositionRequestKeysStart;
    uint256 length = decreasePositionRequestKeys.length;

    if (index >= length) {
      return;
    }

    if (_endIndex > length) {
      _endIndex = length;
    }

    while (index < _endIndex) {
      bytes32 key = decreasePositionRequestKeys[index];

      // if the request was executed then delete the key from the array
      // if the request was not executed then break from the loop, this can happen if the
      // minimum number of blocks has not yet passed
      // an error could be thrown if the request is too old
      // in case an error was thrown, cancel the request
      try
        this.executeDecreasePosition(key, _executionFeeReceiver, index)
      returns (bool _wasExecuted) {
        if (!_wasExecuted) {
          break;
        }
      } catch {
        // wrap this call in a try catch to prevent invalid cancels from blocking the loop
        try
          this.cancelDecreasePosition(key, _executionFeeReceiver, index)
        returns (bool _wasCancelled) {
          if (!_wasCancelled) {
            break;
          }
        } catch {}
      }

      delete decreasePositionRequestKeys[index];
      index++;
    }

    decreasePositionRequestKeysStart = index;
  }

  function executeSwapOrders(
    uint256 _endIndex,
    address payable _executionFeeReceiver
  ) external onlyPositionKeeper {
    uint256 index = swapOrderRequestKeysStart;
    uint256 length = swapOrderRequestKeys.length;

    if (index >= length) {
      return;
    }

    if (_endIndex > length) {
      _endIndex = length;
    }

    while (index < _endIndex) {
      bytes32 key = swapOrderRequestKeys[index];

      // if the request was executed then delete the key from the array
      // if the request was not executed then break from the loop, this can happen if the
      // minimum number of blocks has not yet passed
      // an error could be thrown if the request is too old
      // in case an error was thrown, cancel the request
      try this.executeSwapOrder(key, _executionFeeReceiver, index) returns (
        bool _wasExecuted
      ) {
        if (!_wasExecuted) {
          break;
        }
      } catch {
        // wrap this call in a try catch to prevent invalid cancels from blocking the loop
        try this.cancelSwapOrder(key, _executionFeeReceiver, index) returns (
          bool _wasCancelled
        ) {
          if (!_wasCancelled) {
            break;
          }
        } catch {}
      }

      delete swapOrderRequestKeys[index];
      index++;
    }

    swapOrderRequestKeysStart = index;
  }

  function createIncreasePosition(
    uint256 _subAccountId,
    address[] memory _path,
    address _indexToken,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _sizeDelta,
    bool _isLong,
    uint256 _acceptablePrice,
    uint256 _executionFee
  ) external payable nonReentrant returns (bytes32) {
    if (_executionFee < minExecutionFee) revert InsufficientExecutionFee();
    if (msg.value != _executionFee) revert IncorrectValueTransferred();
    if (_path.length != 1 && _path.length != 2) revert InvalidPathLength();

    _transferInETH();

    if (_amountIn > 0) {
      IERC20Upgradeable(_path[0]).safeTransferFrom(
        msg.sender,
        address(this),
        _amountIn
      );
    }

    return
      _createIncreasePosition(
        msg.sender,
        _subAccountId,
        _path,
        _indexToken,
        _amountIn,
        _minOut,
        _sizeDelta,
        _isLong,
        _acceptablePrice,
        _executionFee,
        false
      );
  }

  function createIncreasePositionNative(
    uint256 _subAccountId,
    address[] memory _path,
    address _indexToken,
    uint256 _minOut,
    uint256 _sizeDelta,
    bool _isLong,
    uint256 _acceptablePrice,
    uint256 _executionFee
  ) external payable nonReentrant returns (bytes32) {
    if (_executionFee < minExecutionFee) revert InsufficientExecutionFee();
    if (msg.value < _executionFee) revert IncorrectValueTransferred();
    if (_path.length != 1 && _path.length != 2) revert InvalidPathLength();
    if (_path[0] != weth) revert InvalidPath();

    _transferInETH();

    uint256 amountIn = msg.value - _executionFee;

    return
      _createIncreasePosition(
        msg.sender,
        _subAccountId,
        _path,
        _indexToken,
        amountIn,
        _minOut,
        _sizeDelta,
        _isLong,
        _acceptablePrice,
        _executionFee,
        true
      );
  }

  function createDecreasePosition(
    uint256 _subAccountId,
    address[] memory _path,
    address _indexToken,
    uint256 _collateralDelta,
    uint256 _sizeDelta,
    bool _isLong,
    address _receiver,
    uint256 _acceptablePrice,
    uint256 _minOut,
    uint256 _executionFee,
    bool _withdrawETH
  ) external payable nonReentrant returns (bytes32) {
    if (_executionFee < minExecutionFee) revert InsufficientExecutionFee();
    if (msg.value != _executionFee) revert IncorrectValueTransferred();
    if (_path.length != 1 && _path.length != 2) revert InvalidPathLength();

    if (_withdrawETH) {
      if (_path[_path.length - 1] != weth) {
        revert InvalidPath();
      }
    }

    _transferInETH();

    return
      _createDecreasePosition(
        msg.sender,
        _subAccountId,
        _path,
        _indexToken,
        _collateralDelta,
        _sizeDelta,
        _isLong,
        _receiver,
        _acceptablePrice,
        _minOut,
        _executionFee,
        _withdrawETH
      );
  }

  function createSwapOrder(
    address[] memory _path,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _executionFee,
    bool _shouldWrap,
    bool _shouldUnwrap
  ) external payable nonReentrant returns (bytes32) {
    if (_path.length != 1 && _path.length != 2) revert InvalidPathLength();
    if (_path[0] == _path[_path.length - 1]) revert InvalidPath();
    if (_amountIn == 0) revert InvalidAmountIn();
    if (_executionFee < minExecutionFee) revert InsufficientExecutionFee();

    // always need this call because of mandatory executionFee user has to transfer in BNB
    _transferInETH();

    if (_shouldWrap) {
      if (_path[0] != weth) revert OnlyNativeShouldWrap();
      if (msg.value != _executionFee + _amountIn)
        revert IncorrectValueTransferred();
    } else {
      if (msg.value != _executionFee) revert IncorrectValueTransferred();
      IERC20Upgradeable(_path[0]).safeTransferFrom(
        msg.sender,
        address(this),
        _amountIn
      );
    }

    return
      _createSwapOrder(
        msg.sender,
        _path,
        _amountIn,
        _minOut,
        _shouldUnwrap,
        _executionFee
      );
  }

  function getRequestQueueLengths()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    return (
      increasePositionRequestKeysStart,
      increasePositionRequestKeys.length,
      decreasePositionRequestKeysStart,
      decreasePositionRequestKeys.length,
      swapOrderRequestKeysStart,
      swapOrderRequestKeys.length
    );
  }

  function executeIncreasePosition(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    IncreasePositionRequest memory request = increasePositionRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeIncreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldExecute = _validateExecution(
      request.blockNumber,
      request.blockTime,
      request.account
    );
    if (!shouldExecute) {
      return false;
    }

    delete increasePositionRequests[_key];

    if (request.amountIn > 0) {
      uint256 amountIn = request.amountIn;

      if (request.path.length > 1) {
        IERC20Upgradeable(request.path[0]).safeTransfer(pool, request.amountIn);
        amountIn = _swap(
          request.account,
          request.path,
          request.minOut,
          address(this)
        );
      }

      uint256 afterFeeAmount = _collectFees(
        msg.sender,
        request.path,
        amountIn,
        request.indexToken,
        request.isLong,
        request.sizeDelta
      );
      IERC20Upgradeable(request.path[request.path.length - 1]).safeTransfer(
        pool,
        afterFeeAmount
      );
    }

    _increasePosition(
      request.account,
      request.subAccountId,
      request.path[request.path.length - 1],
      request.indexToken,
      request.sizeDelta,
      request.isLong,
      request.acceptablePrice
    );

    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit ExecuteIncreasePosition(
      request.account,
      request.subAccountId,
      request.path,
      request.indexToken,
      request.amountIn,
      request.minOut,
      request.sizeDelta,
      request.isLong,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index,
      request.isLong
        ? IPoolOracle(poolOracle).getMaxPrice(request.indexToken)
        : IPoolOracle(poolOracle).getMinPrice(request.indexToken)
    );

    return true;
  }

  function cancelIncreasePosition(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    IncreasePositionRequest memory request = increasePositionRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeIncreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldCancel = _validateCancellation(
      request.blockNumber,
      request.blockTime,
      request.account
    );
    if (!shouldCancel) {
      return false;
    }

    delete increasePositionRequests[_key];

    if (request.hasCollateralInETH) {
      _transferOutETHWithGasLimitIgnoreFail(
        request.amountIn,
        payable(request.account)
      );
    } else {
      IERC20Upgradeable(request.path[0]).safeTransfer(
        request.account,
        request.amountIn
      );
    }

    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit CancelIncreasePosition(
      request.account,
      request.subAccountId,
      request.path,
      request.indexToken,
      request.amountIn,
      request.minOut,
      request.sizeDelta,
      request.isLong,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index
    );

    return true;
  }

  function executeDecreasePosition(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    DecreasePositionRequest memory request = decreasePositionRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldExecute = _validateExecution(
      request.blockNumber,
      request.blockTime,
      request.account
    );
    if (!shouldExecute) {
      return false;
    }

    delete decreasePositionRequests[_key];

    uint256 amountOut = _decreasePosition(
      request.account,
      request.subAccountId,
      request.path[0],
      request.indexToken,
      request.collateralDelta,
      request.sizeDelta,
      request.isLong,
      address(this),
      request.acceptablePrice
    );

    if (amountOut > 0) {
      if (request.path.length > 1) {
        IERC20Upgradeable(request.path[0]).safeTransfer(pool, amountOut);
        amountOut = _swap(
          request.account,
          request.path,
          request.minOut,
          address(this)
        );
      }

      if (request.withdrawETH) {
        _transferOutETHWithGasLimitIgnoreFail(
          amountOut,
          payable(request.receiver)
        );
      } else {
        IERC20Upgradeable(request.path[request.path.length - 1]).safeTransfer(
          request.receiver,
          amountOut
        );
      }
    }

    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit ExecuteDecreasePosition(
      request.account,
      request.subAccountId,
      request.path,
      request.indexToken,
      request.collateralDelta,
      request.sizeDelta,
      request.isLong,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index,
      request.isLong
        ? IPoolOracle(poolOracle).getMinPrice(request.indexToken)
        : IPoolOracle(poolOracle).getMaxPrice(request.indexToken)
    );

    return true;
  }

  function cancelDecreasePosition(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    DecreasePositionRequest memory request = decreasePositionRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldCancel = _validateCancellation(
      request.blockNumber,
      request.blockTime,
      request.account
    );
    if (!shouldCancel) {
      return false;
    }

    delete decreasePositionRequests[_key];

    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit CancelDecreasePosition(
      request.account,
      request.subAccountId,
      request.path,
      request.indexToken,
      request.collateralDelta,
      request.sizeDelta,
      request.isLong,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index
    );

    return true;
  }

  function executeSwapOrder(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    SwapOrderRequest memory request = swapOrderRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeDecreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldExecute = _validateExecution(
      request.blockNumber,
      request.blockTime,
      request.account
    );
    if (!shouldExecute) {
      return false;
    }

    delete swapOrderRequests[_key];

    IERC20Upgradeable(request.path[0]).safeTransfer(pool, request.amountIn);

    uint256 _amountOut;
    if (request.path[request.path.length - 1] == weth && request.shouldUnwrap) {
      _amountOut = _swap(
        request.account,
        request.path,
        request.minOut,
        address(this)
      );
      _transferOutETHWithGasLimitIgnoreFail(
        _amountOut,
        payable(request.account)
      );
    } else {
      _amountOut = _swap(
        request.account,
        request.path,
        request.minOut,
        request.account
      );
    }

    // pay executor
    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit ExecuteSwapOrder(
      request.account,
      request.path,
      request.amountIn,
      request.minOut,
      request.shouldUnwrap,
      request.executionFee,
      _amountOut,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index
    );

    return true;
  }

  function cancelSwapOrder(
    bytes32 _key,
    address payable _executionFeeReceiver,
    uint256 index
  ) public nonReentrant returns (bool) {
    SwapOrderRequest memory request = swapOrderRequests[_key];
    // if the request was already executed or cancelled, return true so that the executeIncreasePositions loop will continue executing the next request
    if (request.account == address(0)) {
      return true;
    }

    bool shouldCancel = _validateCancellation(
      request.blockNumber,
      request.blockTime,
      request.account
    );

    if (!shouldCancel) {
      return false;
    }

    delete swapOrderRequests[_key];

    if (request.path[0] == weth) {
      _transferOutETHWithGasLimitIgnoreFail(
        request.amountIn,
        payable(request.account)
      );
    } else {
      IERC20Upgradeable(request.path[0]).safeTransfer(
        request.account,
        request.amountIn
      );
    }

    // pay executor
    _transferOutETHWithGasLimitIgnoreFail(
      request.executionFee,
      _executionFeeReceiver
    );

    emit CancelSwapOrder(
      request.account,
      request.path,
      request.amountIn,
      request.minOut,
      request.shouldUnwrap,
      request.executionFee,
      block.number - request.blockNumber,
      block.timestamp - request.blockTime,
      index
    );

    return true;
  }

  function getRequestKey(address _account, uint256 _index)
    public
    pure
    returns (bytes32)
  {
    return keccak256(abi.encodePacked(_account, _index));
  }

  function getIncreasePositionRequestPath(bytes32 _key)
    public
    view
    returns (address[] memory)
  {
    IncreasePositionRequest memory request = increasePositionRequests[_key];
    return request.path;
  }

  function getDecreasePositionRequestPath(bytes32 _key)
    public
    view
    returns (address[] memory)
  {
    DecreasePositionRequest memory request = decreasePositionRequests[_key];
    return request.path;
  }

  function getSwapOrderRequestPath(bytes32 _key)
    public
    view
    returns (address[] memory)
  {
    SwapOrderRequest memory request = swapOrderRequests[_key];
    return request.path;
  }

  function _validateMaxGlobalSize(
    address _indexToken,
    bool _isLong,
    uint256 _sizeDelta
  ) internal view {
    if (_sizeDelta == 0) {
      return;
    }

    LibPoolConfigV1.TokenConfig memory config = GetterFacetInterface(pool)
      .tokenMetas(_indexToken);

    if (_isLong) {
      uint256 openInterestDelta = GetterFacetInterface(pool)
        .convertUsde30ToTokens(_indexToken, _sizeDelta, true);
      uint256 maxGlobalLongSize = config.openInterestLongCeiling;
      if (
        maxGlobalLongSize > 0 &&
        GetterFacetInterface(pool).openInterestLong(_indexToken) +
          openInterestDelta >
        maxGlobalLongSize
      ) {
        revert MaxGlobalLongSizesExceeded();
      }
    } else {
      uint256 maxGlobalShortSize = config.shortCeiling;
      if (
        maxGlobalShortSize > 0 &&
        GetterFacetInterface(pool).shortSizeOf(_indexToken) + _sizeDelta >
        maxGlobalShortSize
      ) {
        revert MaxGlobalShortSizesExceeded();
      }
    }
  }

  function _increasePosition(
    address _account,
    uint256 _subAccountId,
    address _collateralToken,
    address _indexToken,
    uint256 _sizeDelta,
    bool _isLong,
    uint256 _price
  ) internal {
    uint256 markPrice = _isLong
      ? IPoolOracle(poolOracle).getMaxPrice(_indexToken)
      : IPoolOracle(poolOracle).getMinPrice(_indexToken);
    bool isPriceValid = _isLong ? markPrice <= _price : markPrice >= _price;
    if (!isPriceValid) {
      revert InvalidPriceForExecution();
    }

    _validateMaxGlobalSize(_indexToken, _isLong, _sizeDelta);

    PerpTradeFacetInterface(pool).increasePosition(
      _account,
      _subAccountId,
      _collateralToken,
      _indexToken,
      _sizeDelta,
      _isLong
    );

    emit IncreasePosition(
      _account,
      _subAccountId,
      _sizeDelta,
      GetterFacetInterface(pool).positionFeeBps()
    );
  }

  function _decreasePosition(
    address _account,
    uint256 _subAccountId,
    address _collateralToken,
    address _indexToken,
    uint256 _collateralDelta,
    uint256 _sizeDelta,
    bool _isLong,
    address _receiver,
    uint256 _price
  ) internal returns (uint256) {
    uint256 markPrice = _isLong
      ? IPoolOracle(poolOracle).getMinPrice(_indexToken)
      : IPoolOracle(poolOracle).getMaxPrice(_indexToken);

    bool isPriceValid = _isLong ? markPrice >= _price : markPrice <= _price;
    if (!isPriceValid) {
      revert InvalidPriceForExecution();
    }

    uint256 amountOut = PerpTradeFacetInterface(pool).decreasePosition(
      _account,
      _subAccountId,
      _collateralToken,
      _indexToken,
      _collateralDelta,
      _sizeDelta,
      _isLong,
      _receiver
    );

    emit DecreasePosition(
      _account,
      _subAccountId,
      _sizeDelta,
      GetterFacetInterface(pool).positionFeeBps()
    );

    return amountOut;
  }

  function _swap(
    address _account,
    address[] memory _path,
    uint256 _minOut,
    address _receiver
  ) internal returns (uint256) {
    if (_path.length == 2) {
      return _poolSwap(_account, _path[0], _path[1], _minOut, _receiver);
    }
    revert InvalidPathLength();
  }

  function _poolSwap(
    address _account,
    address _tokenIn,
    address _tokenOut,
    uint256 _minOut,
    address _receiver
  ) internal returns (uint256) {
    uint256 amountOut = LiquidityFacetInterface(pool).swap(
      _account,
      _tokenIn,
      _tokenOut,
      _minOut,
      _receiver
    );
    if (amountOut < _minOut) {
      revert InsufficientAmountOut();
    }
    return amountOut;
  }

  function _transferInETH() internal {
    if (msg.value != 0) {
      IWNative(weth).deposit{ value: msg.value }();
    }
  }

  function _transferOutETHWithGasLimitIgnoreFail(
    uint256 _amountOut,
    address payable _receiver
  ) internal {
    // prevent istanbul msg.sender.transfer problem
    IERC20Upgradeable(weth).safeTransfer(wnativeRelayer, _amountOut);
    IWNativeRelayer(wnativeRelayer).withdraw(_amountOut);

    // use `send` instead of `transfer` to not revert whole transaction in case ETH transfer was failed
    // it has limit of 2300 gas
    // this is to avoid front-running
    _receiver.send(_amountOut);
  }

  function _collectFees(
    address _account,
    address[] memory _path,
    uint256 _amountIn,
    address _indexToken,
    bool _isLong,
    uint256 _sizeDelta
  ) internal returns (uint256) {
    bool shouldDeductFee = _shouldDeductFee(
      _account,
      _path,
      _amountIn,
      _indexToken,
      _isLong,
      _sizeDelta
    );

    if (shouldDeductFee) {
      uint256 afterFeeAmount = (_amountIn *
        (BASIS_POINTS_DIVISOR - depositFeeBps)) / (BASIS_POINTS_DIVISOR);
      uint256 feeAmount = _amountIn - afterFeeAmount;
      address feeToken = _path[_path.length - 1];
      feeReserves[feeToken] = feeReserves[feeToken] + feeAmount;

      emit CollectFee(feeToken, feeAmount, feeReserves[feeToken]);

      return afterFeeAmount;
    }

    return _amountIn;
  }

  function _shouldDeductFee(
    address _account,
    address[] memory _path,
    uint256 _amountIn,
    address _indexToken,
    bool _isLong,
    uint256 _sizeDelta
  ) internal view returns (bool) {
    // if the position is a short, do not charge a fee
    if (!_isLong) {
      return false;
    }

    // if the position size is not increasing, this is a collateral deposit
    if (_sizeDelta == 0) {
      return true;
    }

    address collateralToken = _path[_path.length - 1];

    GetterFacetInterface.GetPositionReturnVars
      memory position = GetterFacetInterface(pool).getPosition(
        _account,
        collateralToken,
        _indexToken,
        _isLong
      );

    // if there is no existing position, do not charge a fee
    if (position.size == 0) {
      return false;
    }

    uint256 nextSize = position.size + _sizeDelta;
    uint256 collateralDelta = GetterFacetInterface(pool).convertTokensToUsde30(
      collateralToken,
      _amountIn,
      false
    );
    uint256 nextCollateral = position.collateral + collateralDelta;

    uint256 prevLeverage = (position.size * (BASIS_POINTS_DIVISOR)) /
      (position.collateral);
    // allow for a maximum of a increasePositionBufferBps decrease since there might be some swap fees taken from the collateral
    uint256 nextLeverage = (nextSize *
      (BASIS_POINTS_DIVISOR + increasePositionBufferBps)) / nextCollateral;

    // deduct a fee if the leverage is decreased
    return nextLeverage < prevLeverage;
  }

  function _validateExecution(
    uint256 _positionBlockNumber,
    uint256 _positionBlockTime,
    address _account
  ) internal view returns (bool) {
    if (_positionBlockTime + maxTimeDelay <= block.timestamp) {
      revert Expired();
    }

    bool isKeeperCall = msg.sender == address(this) ||
      isPositionKeeper[msg.sender];

    if (!isLeverageEnabled && !isKeeperCall) {
      revert Forbidden();
    }

    if (isKeeperCall) {
      return _positionBlockNumber + minBlockDelayKeeper <= block.number;
    }

    if (msg.sender != _account) {
      revert Forbidden();
    }

    if (_positionBlockTime + minTimeDelayPublic > block.timestamp) {
      revert TooEarly();
    }

    return true;
  }

  function _validateCancellation(
    uint256 _positionBlockNumber,
    uint256 _positionBlockTime,
    address _account
  ) internal view returns (bool) {
    bool isKeeperCall = msg.sender == address(this) ||
      isPositionKeeper[msg.sender];

    if (!isLeverageEnabled && !isKeeperCall) {
      revert Forbidden();
    }

    if (isKeeperCall) {
      return _positionBlockNumber + minBlockDelayKeeper <= block.number;
    }

    if (msg.sender != _account) {
      revert Forbidden();
    }

    if (_positionBlockTime + minTimeDelayPublic > block.timestamp) {
      revert TooEarly();
    }

    return true;
  }

  function _createIncreasePosition(
    address _account,
    uint256 _subAccountId,
    address[] memory _path,
    address _indexToken,
    uint256 _amountIn,
    uint256 _minOut,
    uint256 _sizeDelta,
    bool _isLong,
    uint256 _acceptablePrice,
    uint256 _executionFee,
    bool _hasCollateralInETH
  ) internal returns (bytes32) {
    IncreasePositionRequest memory request = IncreasePositionRequest(
      _account,
      _subAccountId,
      _path,
      _indexToken,
      _amountIn,
      _minOut,
      _sizeDelta,
      _isLong,
      _acceptablePrice,
      _executionFee,
      block.number,
      block.timestamp,
      _hasCollateralInETH
    );

    (uint256 index, bytes32 requestKey) = _storeIncreasePositionRequest(
      request
    );
    emit CreateIncreasePosition(
      _account,
      _subAccountId,
      _path,
      _indexToken,
      _amountIn,
      _minOut,
      _sizeDelta,
      _isLong,
      _acceptablePrice,
      _executionFee,
      index,
      increasePositionRequestKeys.length - 1,
      tx.gasprice
    );

    return requestKey;
  }

  function _storeIncreasePositionRequest(
    IncreasePositionRequest memory _request
  ) internal returns (uint256, bytes32) {
    address account = _request.account;
    uint256 index = increasePositionsIndex[account] + 1;
    increasePositionsIndex[account] = index;
    bytes32 key = getRequestKey(account, index);

    increasePositionRequests[key] = _request;
    increasePositionRequestKeys.push(key);

    return (index, key);
  }

  function _createDecreasePosition(
    address _account,
    uint256 _subAccountId,
    address[] memory _path,
    address _indexToken,
    uint256 _collateralDelta,
    uint256 _sizeDelta,
    bool _isLong,
    address _receiver,
    uint256 _acceptablePrice,
    uint256 _minOut,
    uint256 _executionFee,
    bool _withdrawETH
  ) internal returns (bytes32) {
    DecreasePositionRequest memory request = DecreasePositionRequest(
      _account,
      _subAccountId,
      _path,
      _indexToken,
      _collateralDelta,
      _sizeDelta,
      _isLong,
      _receiver,
      _acceptablePrice,
      _minOut,
      _executionFee,
      block.number,
      block.timestamp,
      _withdrawETH
    );

    (uint256 index, bytes32 requestKey) = _storeDecreasePositionRequest(
      request
    );
    emit CreateDecreasePosition(
      request.account,
      request.subAccountId,
      request.path,
      request.indexToken,
      request.collateralDelta,
      request.sizeDelta,
      request.isLong,
      request.receiver,
      request.acceptablePrice,
      request.minOut,
      request.executionFee,
      index,
      decreasePositionRequestKeys.length - 1
    );
    return requestKey;
  }

  function _storeDecreasePositionRequest(
    DecreasePositionRequest memory _request
  ) internal returns (uint256, bytes32) {
    address account = _request.account;
    uint256 index = decreasePositionsIndex[account] + 1;
    decreasePositionsIndex[account] = index;
    bytes32 key = getRequestKey(account, index);

    decreasePositionRequests[key] = _request;
    decreasePositionRequestKeys.push(key);

    return (index, key);
  }

  function _createSwapOrder(
    address _account,
    address[] memory _path,
    uint256 _amountIn,
    uint256 _minOut,
    bool _shouldUnwrap,
    uint256 _executionFee
  ) internal returns (bytes32) {
    SwapOrderRequest memory request = SwapOrderRequest(
      _account,
      _path,
      _amountIn,
      _minOut,
      _shouldUnwrap,
      _executionFee,
      block.number,
      block.timestamp
    );

    (uint256 index, bytes32 requestKey) = _storeSwapOrderRequest(request);

    emit CreateSwapOrder(
      request.account,
      request.path,
      request.amountIn,
      request.minOut,
      request.shouldUnwrap,
      request.executionFee,
      index,
      swapOrderRequestKeys.length - 1
    );

    return requestKey;
  }

  function _storeSwapOrderRequest(SwapOrderRequest memory _request)
    internal
    returns (uint256, bytes32)
  {
    address account = _request.account;
    uint256 index = swapOrdersIndex[account] + 1;
    swapOrdersIndex[account] = index;
    bytes32 key = getRequestKey(account, index);

    swapOrderRequests[key] = _request;
    swapOrderRequestKeys.push(key);

    return (index, key);
  }

  receive() external payable {
    if (msg.sender != wnativeRelayer) revert InvalidSender();
  }
}
