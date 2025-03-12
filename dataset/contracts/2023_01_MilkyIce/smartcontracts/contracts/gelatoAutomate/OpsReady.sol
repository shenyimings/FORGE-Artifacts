// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './OpsTypes.sol';
import '../utils/NativeTokenReceiver.sol';
import './GelatoAutomation.sol';

/**
 * @dev Inherit this contract to allow your smart contract to
 * - Make synchronous fee payments.
 * - Have call restrictions for functions to be automated.
 */
// solhint-disable private-vars-leading-underscore
abstract contract OpsReady is NativeTokenReceiver, GelatoAutomation {
  IOps public immutable ops;
  address public immutable dedicatedMsgSender;
  address private immutable _gelato;
  address internal constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address private constant OPS_PROXY_FACTORY = 0xC815dB16D4be6ddf2685C201937905aBf338F5D7;

  /**
   * @dev
   * Only tasks created by _taskCreator defined in constructor can call
   * the functions with this modifier.
   */
  modifier automatedTask() {
    _;

    (uint256 fee, address feeToken) = _getFeeDetails();

    _payForTransaction(fee, feeToken);
  }

  /**
   * @dev
   * _taskCreator is the address which will create tasks for this contract.
   */
  constructor(address _ops, address _taskCreator) {
    ops = IOps(_ops);
    _gelato = IOps(_ops).gelato();
    (dedicatedMsgSender, ) = IOpsProxyFactory(OPS_PROXY_FACTORY).getProxyOf(_taskCreator);
  }

  /**
   * @dev
   * Transfers fee to gelato for synchronous fee payments.
   * _fee & _feeToken should be queried from IOps.getFeeDetails()
   */
  function _payForTransaction(uint256 _fee, address _feeToken) internal {
    if (_feeToken == NATIVE_TOKEN || _feeToken == address(0)) {
      (bool success, ) = _gelato.call{value: _fee}('');
      require(success, '_payForTransaction: NATIVE_TOKEN transfer failed');
    } else {
      SafeERC20.safeTransfer(IERC20(_feeToken), _gelato, _fee);
    }
  }

  function _getFeeDetails() internal view returns (uint256 fee, address feeToken) {
    (fee, feeToken) = ops.getFeeDetails();
  }

  function _createTask(
    address _resolverAddress,
    bytes memory _resolverData,
    address execAddress,
    bytes memory execDataOrSelector
  ) internal {
    if (automationTaskId != bytes32('')) {
      revert('createTask: Task already scheduled');
    }
    ModuleData memory moduleData = ModuleData({
      modules: new Module[](1),
      args: new bytes[](1)
    });
    moduleData.modules[0] = Module.RESOLVER;
    moduleData.args[0] = _resolverModuleArg(_resolverAddress, _resolverData);

    automationTaskId = ops.createTask(
      execAddress,
      execDataOrSelector,
      moduleData,
      NATIVE_TOKEN
    );

    emit TaskScheduled(block.timestamp, automationTaskId);
  }

  function _cancelTask() internal {
    ops.cancelTask(automationTaskId);
    emit TaskCancelled(block.timestamp, automationTaskId);
    automationTaskId = bytes32('');
  }

  function _resolverModuleArg(
    address _resolverAddress,
    bytes memory _resolverData
  ) internal pure returns (bytes memory) {
    return abi.encode(_resolverAddress, _resolverData);
  }

  function _timeModuleArg(
    uint256 _startTime,
    uint256 _interval
  ) internal pure returns (bytes memory) {
    return abi.encode(uint128(_startTime), uint128(_interval));
  }
}
