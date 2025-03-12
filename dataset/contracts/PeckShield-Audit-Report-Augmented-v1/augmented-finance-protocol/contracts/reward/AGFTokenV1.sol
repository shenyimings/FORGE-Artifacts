// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {AccessFlags} from '../access/AccessFlags.sol';
import {MarketAccessBitmask} from '../access/MarketAccessBitmask.sol';
import {IMarketAccessController} from '../access/interfaces/IMarketAccessController.sol';

import {IRewardMinter} from '../interfaces/IRewardMinter.sol';
import {RewardToken} from './RewardToken.sol';
import {VersionedInitializable} from '../tools/upgradeability/VersionedInitializable.sol';
import {IInitializableRewardToken} from './interfaces/IInitializableRewardToken.sol';

import 'hardhat/console.sol';

contract AGFTokenV1 is
  RewardToken,
  MarketAccessBitmask,
  VersionedInitializable,
  IInitializableRewardToken,
  IRewardMinter
{
  string internal constant NAME = 'Augmented Finance Reward Token';
  string internal constant SYMBOL = 'AGF';
  uint8 internal constant DECIMALS = 18;

  uint256 private constant TOKEN_REVISION = 1;

  constructor()
    public
    RewardToken(NAME, SYMBOL, DECIMALS)
    MarketAccessBitmask(IMarketAccessController(0))
  {}

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  // This initializer is invoked by AccessController.setAddressAsImpl
  function initialize(IMarketAccessController remoteAcl)
    external
    virtual
    initializerRunAlways(TOKEN_REVISION)
  {
    _initialize(remoteAcl, NAME, SYMBOL, DECIMALS);
  }

  function initialize(InitData calldata data)
    public
    virtual
    override
    initializerRunAlways(TOKEN_REVISION)
  {
    _initialize(data.remoteAcl, data.name, data.symbol, data.decimals);
  }

  function _initialize(
    IMarketAccessController remoteAcl,
    string memory name,
    string memory symbol,
    uint8 decimals
  ) private {
    super._initializeERC20(name, symbol, decimals);
    _remoteAcl = remoteAcl;
    if (!isRevisionInitialized(TOKEN_REVISION)) {
      super._initializeDomainSeparator();
    }
  }

  function mintReward(
    address account,
    uint256 amount,
    bool
  ) external override aclAnyOf(AccessFlags.REWARD_MINT | AccessFlags.REWARD_CONTROLLER) {
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external aclHas(AccessFlags.REWARD_BURN) {
    _burn(account, amount);
  }

  function _checkTransfer(address from, address to) internal view virtual {
    // require(_getRemoteAcl(from) & AccessFlags.REWARD_SUSPEND_USER == 0, 'sender is suspended');
    // if (from == to) {
    //   return;
    // }
    // require(_getRemoteAcl(to) & AccessFlags.REWARD_SUSPEND_USER == 0, 'receiver is suspended');
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);
    _checkTransfer(from, to);
  }
}
