// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import { Operator } from "../utils/Operator.sol";
import { IOperation } from "../operations/Operation.sol";
import { IOperationStore } from "../operations/OperationStore.sol";
import { IOperationFactory } from "../operations/OperationFactory.sol";

interface IController {
  function allocate(uint256 _amount) external;

  function finish(address _opt) external;

  function flush(uint256 _amount) external;

  function halt(address _opt) external;

  function emergencyWithdraw(
    address _opt,
    address _token,
    address _to
  ) external;

  function emergencyWithdraw(address _opt, address payable _to) external;

  function recover(address _opt, bool _runFinish) external;
}

contract Controller is IController, Context, Operator, Initializable {
  using SafeERC20 for IERC20;

  uint256 public optStdId;
  address public optStore;
  address public optFactory;

  function initialize(
    address _optStore,
    uint256 _optStdId,
    address _optFactory
  ) public initializer {
    optStore = _optStore;
    optStdId = _optStdId;
    optFactory = _optFactory;

    setRole(_msgSender(), _msgSender());
  }

  function allocate(uint256 _amount) public override onlyGranted {
    for (uint256 i = 0; i < _amount; i++) {
      address instance = IOperationFactory(optFactory).build(optStdId);
      IOperationStore(optStore).allocate(instance);
    }
  }

  function finish(address _opt) public override onlyGranted {
    IOperationStore.Status status = IOperationStore(optStore).getStatusOf(_opt);

    require(
      status == IOperationStore.Status.RUNNING_AUTO,
      "Controller: invalid status for finish"
    );

    IOperation(_opt).finish();
    IOperationStore(optStore).finish(_opt);
  }

  function flush(uint256 _amount) public override onlyGranted {
    IOperationStore(optStore).flushAll(_amount);
  }

  function halt(address _opt) public override onlyGranted {
    IOperation(_opt).halt();
    IOperationStore(optStore).halt(_opt);
  }

  function emergencyWithdraw(
    address _opt,
    address _token,
    address _to
  ) public override onlyOwner {
    IOperation(_opt).emergencyWithdraw(_token, _to);
  }

  function emergencyWithdraw(address _opt, address payable _to)
    public
    override
    onlyOwner
  {
    IOperation(_opt).emergencyWithdraw(_to);
  }

  function recover(address _opt, bool _runFinish) public override onlyGranted {
    IOperation(_opt).recover();
    IOperationStore(optStore).recover(_opt);

    if (_runFinish) {
      IOperation(_opt).finish();
    }
  }
}
