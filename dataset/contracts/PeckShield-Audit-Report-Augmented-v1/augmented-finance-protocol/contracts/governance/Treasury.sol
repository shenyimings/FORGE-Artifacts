// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {IERC20} from '../dependencies/openzeppelin/contracts/IERC20.sol';
import {VersionedInitializable} from '../tools/upgradeability/VersionedInitializable.sol';
import {MarketAccessBitmask} from '../access/MarketAccessBitmask.sol';
import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';
import {AccessFlags} from '../access/AccessFlags.sol';
import {IRewardCollector} from '../reward/interfaces/IRewardCollector.sol';

import 'hardhat/console.sol';

contract Treasury is VersionedInitializable, MarketAccessBitmask {
  uint256 private constant TREASURY_REVISION = 1;

  constructor() public MarketAccessBitmask(IMarketAccessController(0)) {}

  // This initializer is invoked by AccessController.setAddressAsImpl
  function initialize(address remoteAcl) external virtual initializerRunAlways(TREASURY_REVISION) {
    _remoteAcl = IMarketAccessController(remoteAcl);
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return TREASURY_REVISION;
  }

  function approve(
    address token,
    address recipient,
    uint256 amount
  ) external aclHas(AccessFlags.TREASURY_ADMIN) {
    IERC20(token).approve(recipient, amount);
  }

  function transfer(
    address token,
    address recipient,
    uint256 amount
  ) external aclHas(AccessFlags.TREASURY_ADMIN) {
    if (token == _remoteAcl.getRewardToken() && IERC20(token).balanceOf(address(this)) < amount) {
      _claimRewards();
    }
    IERC20(token).transfer(recipient, amount);
  }

  function _claimRewards() private {
    address rc = _remoteAcl.getRewardController();
    if (rc != address(0)) {
      IRewardCollector(rc).claimReward();
    }
  }

  function claimRewardsForTreasury() external aclHas(AccessFlags.TREASURY_ADMIN) {
    _claimRewards();
  }

  function _safeTransferETH(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'ETH_TRANSFER_FAILED');
  }

  function transferEth(address recipient, uint256 amount)
    external
    aclHas(AccessFlags.TREASURY_ADMIN)
  {
    _safeTransferETH(recipient, amount);
  }
}
