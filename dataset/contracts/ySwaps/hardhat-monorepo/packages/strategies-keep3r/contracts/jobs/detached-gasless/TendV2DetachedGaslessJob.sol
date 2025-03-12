// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import '../../interfaces/yearn/IBaseStrategy.sol';
import './V2DetachedGaslessJob.sol';

contract TendV2DetachedGaslessJob is V2DetachedGaslessJob {
  constructor(
    address _WETH,
    address _mechanicsRegistry,
    address _v2Keeper,
    uint256 _workCooldown,
    uint256 _callCost
  )
    V2DetachedGaslessJob(_WETH, _mechanicsRegistry, _v2Keeper, _workCooldown, _callCost) // solhint-disable-next-line no-empty-blocks
  {}

  function workable(address _strategy) external view override returns (bool) {
    return _workable(_strategy);
  }

  function _workable(address _strategy) internal view override returns (bool) {
    if (!super._workable(_strategy)) return false;
    return IBaseStrategy(_strategy).tendTrigger(callCost);
  }

  function _work(address _strategy) internal override {
    lastWorkAt[_strategy] = block.timestamp;
    V2Keeper.tend(_strategy);
  }

  // Keep3r actions
  function work(address _strategy) external override notPaused onlyGovernorOrMechanic {
    _workInternal(_strategy);
  }
}
