// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IBalanceHook} from '../../interfaces/IBalanceHook.sol';
import {IScaledBalanceToken} from '../../interfaces/IScaledBalanceToken.sol';

contract DepositTokenMock is IScaledBalanceToken {
  IBalanceHook public _aic;
  uint256 internal _userBalance;
  uint256 internal _totalSupply;

  // hack to be able to test event from EI properly
  event RewardsAccrued(address indexed user, uint256 amount);

  // hack to be able to test event from Distribution manager properly
  event AssetConfigUpdated(address indexed asset, uint256 emission);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  constructor(IBalanceHook aic) public {
    _aic = aic;
  }

  function handleActionOnAic(
    address user,
    uint256 oldBalance,
    uint256 newBalance,
    uint256 totalSupply
  ) external {
    _aic.handleBalanceUpdate(address(this), user, oldBalance, newBalance, totalSupply);
  }

  function setUserBalanceAndSupply(uint256 userBalance, uint256 totalSupply) public {
    _userBalance = userBalance;
    _totalSupply = totalSupply;
  }

  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    user;
    return (_userBalance, _totalSupply);
  }

  function scaledBalanceOf(address user) external view override returns (uint256) {
    user;
    return _userBalance;
  }

  function scaledTotalSupply() external view override returns (uint256) {
    return _totalSupply;
  }

  function cleanUserState() external {
    _userBalance = 0;
    _totalSupply = 0;
  }
}
