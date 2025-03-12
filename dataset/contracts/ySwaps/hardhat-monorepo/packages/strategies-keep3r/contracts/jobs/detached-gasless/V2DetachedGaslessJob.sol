// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@yearn-mechanics/contract-utils/solidity/contracts/abstract/MachineryReady.sol';

import '../../interfaces/jobs/detached/IV2DetachedGaslessJob.sol';

abstract contract V2DetachedGaslessJob is MachineryReady, IV2DetachedGaslessJob {
  using EnumerableSet for EnumerableSet.AddressSet;

  address public immutable override WETH;
  IV2Keeper public override V2Keeper;

  EnumerableSet.AddressSet internal _availableStrategies;

  mapping(address => uint256) public override lastWorkAt;

  uint256 public override workCooldown;
  uint256 public override callCost;

  constructor(
    address _WETH,
    address _mechanicsRegistry,
    address _v2Keeper,
    uint256 _workCooldown,
    uint256 _callCost
  ) MachineryReady(_mechanicsRegistry) {
    if (_workCooldown > 0) workCooldown = _workCooldown;
    V2Keeper = IV2Keeper(_v2Keeper);
    WETH = _WETH;
    callCost = _callCost;
  }

  function setV2Keep3r(address _v2Keeper) external override onlyGovernor {
    V2Keeper = IV2Keeper(_v2Keeper);
  }

  // Setters
  function setWorkCooldown(uint256 _workCooldown) external override onlyGovernorOrMechanic {
    if (_workCooldown == 0) revert NotZero();
    workCooldown = _workCooldown;
  }

  function setCallCost(uint256 _callCost) external override onlyGovernorOrMechanic {
    if (_callCost == 0) revert NotZero();
    callCost = _callCost;
  }

  // Governor
  function addStrategies(address[] calldata _strategies) external override onlyGovernorOrMechanic {
    for (uint256 i; i < _strategies.length; i++) {
      if (!_availableStrategies.add(_strategies[i])) revert StrategyAlreadyAdded();
    }
    emit StrategiesAdded(_strategies);
  }

  function removeStrategies(address[] calldata _strategies) external override onlyGovernorOrMechanic {
    for (uint256 i; i < _strategies.length; i++) {
      if (!_availableStrategies.remove(_strategies[i])) revert StrategyNotAdded();
    }
    emit StrategiesRemoved(_strategies);
  }

  // Getters
  function strategies() public view override returns (address[] memory _strategies) {
    _strategies = _availableStrategies.values();
  }

  // Keeper view actions (internal)
  function _workable(address _strategy) internal view virtual returns (bool) {
    if (!_availableStrategies.contains(_strategy)) revert StrategyNotAdded();
    if (workCooldown == 0 || block.timestamp > lastWorkAt[_strategy] + workCooldown) return true;
    return false;
  }

  // Keeper actions
  function _workInternal(address _strategy) internal {
    if (!_workable(_strategy)) revert NotWorkable();
    _work(_strategy);
    emit Worked(_strategy, msg.sender);
  }

  function forceWork(address _strategy) external override onlyGovernorOrMechanic {
    _work(_strategy);
    emit ForceWorked(_strategy);
  }

  function _work(address _strategy) internal virtual {}
}
