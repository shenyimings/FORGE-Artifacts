// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { Ownable } from "../utils/Ownable.sol";
import { StdQueue } from "../utils/Queue.sol";
import { IOperation } from "../operations/Operation.sol";
import { IOperationStore } from "../operations/OperationStore.sol";
import { IOperationFactory } from "../operations/OperationFactory.sol";

interface IRouter {
  // ======================= common ======================= //

  function init(
    IOperation.Type _type,
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) external;

  function finish(address _operation) external;

  // ======================= deposit stable ======================= //

  function depositStable(uint256 _amount) external;

  function depositStable(address _operator, uint256 _amount) external;

  function initDepositStable(uint256 _amount) external;

  function finishDepositStable(address _operation) external;

  // ======================= redeem stable ======================= //

  function redeemStable(uint256 _amount) external;

  function redeemStable(address _operator, uint256 _amount) external;

  function initRedeemStable(uint256 _amount) external;

  function finishRedeemStable(address _operation) external;
}

interface IConversionRouter {
  // ======================= deposit stable ======================= //

  function depositStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) external;

  function initDepositStable(
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) external;

  // ======================= redeem stable ======================= //

  function redeemStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) external;

  function initRedeemStable(
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) external;
}

contract Router is IRouter, IConversionRouter, Context, Ownable, Initializable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // operation
  address public optStore;
  uint256 public optStdId;
  address public optFactory;

  // constant
  address public wUST;
  address public aUST;

  // flags
  bool public isDepositAllowed = true;
  bool public isRedemptionAllowed = true;

  function initialize(
    address _optStore,
    uint256 _optStdId,
    address _optFactory,
    address _wUST,
    address _aUST
  ) public initializer {
    optStore = _optStore;
    optStdId = _optStdId;
    optFactory = _optFactory;
    wUST = _wUST;
    aUST = _aUST;
    setOwner(msg.sender);
  }

  function setOperationStore(address _store) public onlyOwner {
    optStore = _store;
  }

  function setOperationId(uint256 _optStdId) public onlyOwner {
    optStdId = _optStdId;
  }

  function setOperationFactory(address _factory) public onlyOwner {
    optFactory = _factory;
  }

  function setDepositAllowance(bool _allow) public onlyOwner {
    isDepositAllowed = _allow;
  }

  function setRedemptionAllowance(bool _allow) public onlyOwner {
    isRedemptionAllowed = _allow;
  }

  function _init(
    IOperation.Type _typ,
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) internal {
    IOperationStore store = IOperationStore(optStore);
    if (store.getAvailableOperation() == address(0x0)) {
      address instance = IOperationFactory(optFactory).build(optStdId);
      store.allocate(instance);
    }
    IOperation operation = IOperation(store.init(_autoFinish));

    // check allowance
    if (IERC20(wUST).allowance(address(this), address(operation)) == 0) {
      IERC20(wUST).safeApprove(address(operation), type(uint256).max);
      IERC20(aUST).safeApprove(address(operation), type(uint256).max);
    }

    if (_typ == IOperation.Type.DEPOSIT) {
      IERC20(wUST).safeTransferFrom(_msgSender(), address(this), _amount);
      operation.initDepositStable(
        _operator,
        _amount,
        _swapper,
        _swapDest,
        _autoFinish
      );
      return;
    }

    if (_typ == IOperation.Type.REDEEM) {
      IERC20(aUST).safeTransferFrom(_msgSender(), address(this), _amount);
      operation.initRedeemStable(
        _operator,
        _amount,
        _swapper,
        _swapDest,
        _autoFinish
      );
      return;
    }

    revert("Router: invalid operation type");
  }

  function _finish(address _opt) internal {
    IOperationStore.Status status = IOperationStore(optStore).getStatusOf(_opt);

    if (status == IOperationStore.Status.RUNNING_MANUAL) {
      // check sender
      require(
        IOperation(_opt).getCurrentStatus().operator == _msgSender(),
        "Router: invalid sender"
      );
    } else {
      revert("Router: invalid status for finish");
    }

    IOperation(_opt).finish();
    IOperationStore(optStore).finish(_opt);
  }

  // =================================== COMMON =================================== //

  function init(
    IOperation.Type _type,
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest,
    bool _autoFinish
  ) public override {
    _init(_type, _operator, _amount, _swapper, _swapDest, _autoFinish);
  }

  function finish(address _operation) public override {
    _finish(_operation);
  }

  // =================================== DEPOSIT STABLE =================================== //

  function depositStable(uint256 _amount) public override {
    _init(
      IOperation.Type.DEPOSIT,
      _msgSender(),
      _amount,
      address(0x0),
      address(0x0),
      true
    );
  }

  function depositStable(address _operator, uint256 _amount) public override {
    _init(
      IOperation.Type.DEPOSIT,
      _operator,
      _amount,
      address(0x0),
      address(0x0),
      true
    );
  }

  function depositStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) public override {
    _init(
      IOperation.Type.DEPOSIT,
      _operator,
      _amount,
      _swapper,
      _swapDest,
      true
    );
  }

  function initDepositStable(uint256 _amount) public override {
    _init(
      IOperation.Type.DEPOSIT,
      _msgSender(),
      _amount,
      address(0x0),
      address(0x0),
      false
    );
  }

  function initDepositStable(
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) public override {
    _init(
      IOperation.Type.DEPOSIT,
      _msgSender(),
      _amount,
      _swapper,
      _swapDest,
      false
    );
  }

  function finishDepositStable(address _operation) public override {
    _finish(_operation);
  }

  // =================================== REDEEM STABLE =================================== //

  function redeemStable(uint256 _amount) public override {
    _init(
      IOperation.Type.REDEEM,
      _msgSender(),
      _amount,
      address(0x0),
      address(0x0),
      true
    );
  }

  function redeemStable(address _operator, uint256 _amount) public override {
    _init(
      IOperation.Type.REDEEM,
      _operator,
      _amount,
      address(0x0),
      address(0x0),
      true
    );
  }

  function redeemStable(
    address _operator,
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) public override {
    _init(
      IOperation.Type.REDEEM,
      _operator,
      _amount,
      _swapper,
      _swapDest,
      true
    );
  }

  function initRedeemStable(uint256 _amount) public override {
    _init(
      IOperation.Type.REDEEM,
      _msgSender(),
      _amount,
      address(0x0),
      address(0x0),
      false
    );
  }

  function initRedeemStable(
    uint256 _amount,
    address _swapper,
    address _swapDest
  ) public override {
    _init(
      IOperation.Type.REDEEM,
      _msgSender(),
      _amount,
      _swapper,
      _swapDest,
      false
    );
  }

  function finishRedeemStable(address _operation) public override {
    _finish(_operation);
  }
}
