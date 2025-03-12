// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { IWrappedAsset } from "../assets/IWrappedAsset.sol";
import { Operator } from "../utils/Operator.sol";
import { OperationACL } from "./OperationACL.sol";
import { ISwapper } from "../swapper/ISwapper.sol";

interface IOperation {
  // Events
  event AutoFinishEnabled(address indexed operation);
  event InitDeposit(address indexed operator, uint256 amount, bytes32 to);
  event FinishDeposit(address indexed operator, uint256 amount);
  event InitRedemption(address indexed operator, uint256 amount, bytes32 to);
  event FinishRedemption(address indexed operator, uint256 amount);
  event EmergencyWithdrawActivated(address token, uint256 amount);

  // Data Structure
  enum Status {
    IDLE,
    RUNNING,
    STOPPED
  }
  enum Type {
    NEUTRAL,
    DEPOSIT,
    REDEEM
  }

  struct Info {
    Status status;
    Type typ;
    address operator;
    uint256 amount;
    address input;
    address output;
    address swapper;
    address swapDest;
  }

  // Interfaces

  function terraAddress() external view returns (bytes32);

  function getCurrentStatus() external view returns (Info memory);

  function initDepositStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) external;

  function initRedeemStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) external;

  function finish() external;

  function finish(uint256 _minAmountOut) external;

  function finishDepositStable() external;

  function finishRedeemStable() external;

  function halt() external;

  function recover() external;

  function emergencyWithdraw(address _token, address _to) external;

  function emergencyWithdraw(address payable _to) external;
}

// Operation.sol: subcontract generated per wallet, defining all relevant wrapping functions
contract Operation is Context, OperationACL, IOperation, Initializable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using SafeERC20 for IWrappedAsset;

  Info public DEFAULT_STATUS =
    Info({
      status: Status.IDLE,
      typ: Type.NEUTRAL,
      operator: address(0x0),
      amount: 0,
      input: address(0x0),
      output: address(0x0),
      swapper: address(0x0),
      swapDest: address(0x0)
    });
  Info public currentStatus;

  IWrappedAsset public wUST;
  IWrappedAsset public aUST;

  bytes32 public override terraAddress;

  function initialize(bytes memory args) public initializer {
    (
      address _router,
      address _controller,
      bytes32 _terraAddress,
      address _wUST,
      address _aUST
    ) = abi.decode(args, (address, address, bytes32, address, address));

    currentStatus = DEFAULT_STATUS;
    terraAddress = _terraAddress;
    wUST = IWrappedAsset(_wUST);
    aUST = IWrappedAsset(_aUST);

    router = _router;
    controller = _controller;
  }

  function initPayload(
    address _router,
    address _controller,
    bytes32 _terraAddress
  ) public view returns (bytes memory) {
    return abi.encode(_router, _controller, _terraAddress, wUST, aUST);
  }

  modifier checkStopped {
    require(currentStatus.status != Status.STOPPED, "Operation: stopped");

    _;
  }

  function getCurrentStatus() public view override returns (Info memory) {
    return currentStatus;
  }

  function _init(
    Type _typ,
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) private onlyRouter checkStopped {
    require(currentStatus.status == Status.IDLE, "Operation: running");
    require(_amount >= 10 ether, "Operation: amount must be more than 10");

    currentStatus = Info({
      status: Status.RUNNING,
      typ: _typ,
      operator: _operator,
      amount: _amount,
      input: address(0x0),
      output: address(0x0),
      swapper: _swapper,
      swapDest: _swapDest
    });

    if (_typ == Type.DEPOSIT) {
      currentStatus.input = address(wUST);
      currentStatus.output = address(aUST);

      wUST.safeTransferFrom(_msgSender(), address(this), _amount);
      wUST.burn(_amount, terraAddress);

      emit InitDeposit(_operator, _amount, terraAddress);
    } else if (_typ == Type.REDEEM) {
      currentStatus.input = address(aUST);
      currentStatus.output = address(wUST);

      aUST.safeTransferFrom(_msgSender(), address(this), _amount);
      aUST.burn(_amount, terraAddress);

      emit InitRedemption(_operator, _amount, terraAddress);
    } else {
      revert("Operation: invalid operation type");
    }

    if (_autoFinish) {
      emit AutoFinishEnabled(address(this));
    }
  }

  function initDepositStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) public override {
    _init(Type.DEPOSIT, _operator, _amount, _swapper, _swapDest, _autoFinish);
  }

  function initRedeemStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) public override {
    _init(Type.REDEEM, _operator, _amount, _swapper, _swapDest, _autoFinish);
  }

  function _finish(uint256 _minAmountOut)
    private
    onlyGranted
    checkStopped
    returns (address, uint256)
  {
    // check status
    require(currentStatus.status == Status.RUNNING, "Operation: idle");

    IWrappedAsset output = IWrappedAsset(currentStatus.output);
    uint256 amount = output.balanceOf(address(this));
    address operator = currentStatus.operator;
    address swapper = currentStatus.swapper;

    require(amount > 0, "Operation: not enough token");

    if (swapper != address(0x0)) {
      output.safeIncreaseAllowance(swapper, amount);

      try
        ISwapper(swapper).swapToken(
          address(output),
          currentStatus.swapDest,
          amount,
          _minAmountOut,
          operator
        )
      {} catch {
        output.safeDecreaseAllowance(swapper, amount);
        output.safeTransfer(operator, amount);
      }
    } else {
      output.safeTransfer(operator, amount);
    }

    // state reference gas optimization
    Type typ = currentStatus.typ;

    if (typ == Type.DEPOSIT) {
      emit FinishDeposit(operator, amount);
    } else if (typ == Type.REDEEM) {
      emit FinishRedemption(operator, amount);
    }

    // reset
    currentStatus = DEFAULT_STATUS;

    return (address(output), amount);
  }

  function finish() public override {
    _finish(0);
  }

  function finish(uint256 _minAmountOut) public override {
    _finish(_minAmountOut);
  }

  function finishDepositStable() public override {
    _finish(0);
  }

  function finishRedeemStable() public override {
    _finish(0);
  }

  function halt() public override onlyController {
    currentStatus.status = Status.STOPPED;
  }

  function recover() public override onlyController {
    if (currentStatus.operator == address(0x0)) {
      currentStatus.status = Status.IDLE;
    } else {
      currentStatus.status = Status.RUNNING;
    }
  }

  function emergencyWithdraw(address _token, address _to)
    public
    override
    onlyController
  {
    require(
      currentStatus.status == Status.STOPPED,
      "Operation: not an emergency"
    );

    if (currentStatus.operator != address(0x0)) {
      require(currentStatus.output != _token, "Operation: withdrawal rejected");
    }

    IERC20(_token).safeTransfer(_to, IERC20(_token).balanceOf(address(this)));
  }

  function emergencyWithdraw(address payable _to)
    public
    override
    onlyController
  {
    require(
      currentStatus.status == Status.STOPPED,
      "Operation: not an emergency"
    );

    _to.transfer(address(this).balance);
  }
}
