// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/access/Ownable.sol';
import {Staking} from './Staking.sol';
import '../gelatoAutomate/OpsReady.sol';
import '../tokens/MultiERC20WeightedLocker.sol';

error StaleDepositLiquidator__TaskAlreadyCreated();

struct DepositToLiquidate {
  address depositor;
  uint256 depositId;
}

contract StaleDepositLiquidator is Ownable, OpsReady {
  MultiERC20WeightedLocker public immutable locker;

  constructor(
    address _ops,
    MultiERC20WeightedLocker _lockerContract
  ) OpsReady(_ops, address(this)) {
    locker = _lockerContract;
  }

  // ======== AUTOMATION FUNCTIONS ========

  function createTask() external override onlyOwner {
    super._createTask(
      address(this),
      abi.encodeCall(this.getListOfStaleDepositsToLiquidate, ()),
      address(this),
      abi.encode(this.liquidateStaleDeposits.selector)
    );
  }

  function cancelTask() external override onlyOwner {
    super._cancelTask();
  }

  // ======== PUBLIC FUNCTIONS ========

  function withdrawFunds() external onlyOwner {
    _withdrawNativeToken(payable(owner()));
  }

  function liquidateStaleDeposits(
    DepositToLiquidate[] calldata depositsToLiquidate
  ) external automatedTask {
    for (uint256 i = 0; i < depositsToLiquidate.length; i++) {
      DepositToLiquidate memory depositToLiquidate = depositsToLiquidate[i];
      locker.liquidateStaleDeposit(
        depositToLiquidate.depositor,
        depositToLiquidate.depositId
      );
    }
  }

  function getListOfStaleDepositsToLiquidate()
    external
    view
    returns (bool canExec, bytes memory execPayload)
  {
    DepositToLiquidate[] memory allDeposits = new DepositToLiquidate[](
      locker.currentDepositId()
    );
    uint256 amountOfDepositsToLiquidate = 0;

    uint256 depositorsCount = locker.getDepositorsCount();
    for (uint i = 0; i < depositorsCount; i++) {
      address depositor = locker.getDepositor(i);
      uint256 depositsCount = locker.userDepositsCount(depositor);
      for (uint j = 0; j < depositsCount; j++) {
        uint256 depositId = locker.userDepositIds(depositor, j);
        Deposit memory deposit = locker.getDeposit(depositor, depositId);
        if (
          deposit.isOngoing &&
          deposit.lockPeriod.durationInSeconds != 0 &&
          deposit.unlockAvailibleTimestamp < block.timestamp
        ) {
          allDeposits[amountOfDepositsToLiquidate] = DepositToLiquidate(
            depositor,
            depositId
          );
          amountOfDepositsToLiquidate++;
        }
      }
    }
    if (amountOfDepositsToLiquidate == 0) {
      return (false, bytes('No deposits to liquidate'));
    }

    return (
      true,
      abi.encodeWithSelector(
        this.liquidateStaleDeposits.selector,
        _sliceDepositsArray(allDeposits, amountOfDepositsToLiquidate)
      )
    );
  }

  // ======== INTERNAL FUNCTIONS ========

  function getRangeFromArray(
    uint256[] memory _array,
    uint256 _start,
    uint256 _end
  ) internal pure returns (uint256[] memory) {
    uint256[] memory result = new uint256[](_end - _start);
    for (uint256 i = _start; i < _end; i++) {
      result[i - _start] = _array[i];
    }
    return result;
  }

  /**
   * @dev Slice array of deposits to liquidate. It is used to remove empty elements from input array.
   */
  function _sliceDepositsArray(
    DepositToLiquidate[] memory _array,
    uint256 amount
  ) internal pure returns (DepositToLiquidate[] memory) {
    DepositToLiquidate[] memory result = new DepositToLiquidate[](amount);
    for (uint256 i = 0; i < amount; i++) {
      result[i] = _array[i];
    }
    return result;
  }
}
