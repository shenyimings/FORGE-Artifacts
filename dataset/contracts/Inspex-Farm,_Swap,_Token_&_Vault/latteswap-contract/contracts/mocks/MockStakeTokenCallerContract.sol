// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../farm/interfaces/IMasterBaristaCallback.sol";
import "../farm/interfaces/IMasterBarista.sol";

contract MockStakeTokenCallerContract is IMasterBaristaCallback {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  address public stakeToken;
  address public latte;
  IMasterBarista public masterBarista;

  event OnBeforeLock();

  constructor(
    address _latte,
    address _stakeToken,
    IMasterBarista _masterBarista
  ) public {
    latte = _latte;
    stakeToken = _stakeToken;
    masterBarista = _masterBarista;
  }

  function _withdrawFromMasterBarista(IERC20 _stakeToken, uint256 _shares) internal returns (uint256 reward) {
    if (_shares == 0) return 0;
    uint256 stakeTokenBalance = _stakeToken.balanceOf(address(this));
    if (address(_stakeToken) == address(latte)) {
      masterBarista.withdrawLatte(msg.sender, _shares);
    } else {
      masterBarista.withdraw(msg.sender, address(_stakeToken), _shares);
    }
    reward = address(latte) == address(_stakeToken)
      ? _stakeToken.balanceOf(address(this)).sub(stakeTokenBalance)
      : IERC20(latte).balanceOf(address(this));
    return reward;
  }

  function _harvestFromMasterBarista(IERC20 _stakeToken) internal returns (uint256 reward) {
    uint256 stakeTokenBalance = _stakeToken.balanceOf(address(this));
    (uint256 userStakeAmount, , , ) = masterBarista.userInfo(address(address(_stakeToken)), msg.sender);

    if (userStakeAmount == 0) return 0;

    masterBarista.harvest(msg.sender, address(_stakeToken));
    reward = address(latte) == address(_stakeToken)
      ? _stakeToken.balanceOf(address(this)).sub(stakeTokenBalance)
      : IERC20(latte).balanceOf(address(this));
    return reward;
  }

  function stake(IERC20 _stakeToken, uint256 _amount) external {
    _harvestFromMasterBarista(_stakeToken);

    IERC20(_stakeToken).safeApprove(address(masterBarista), uint256(-1));
    if (address(_stakeToken) == address(latte)) {
      masterBarista.depositLatte(msg.sender, _amount);
    } else {
      masterBarista.deposit(msg.sender, address(_stakeToken), _amount);
    }
  }

  function _unstake(IERC20 _stakeToken, uint256 _amount) internal {
    _withdrawFromMasterBarista(_stakeToken, _amount);
  }

  function unstake(address _stakeToken, uint256 _amount) external {
    _unstake(IERC20(_stakeToken), _amount);
  }

  function harvest(address _stakeToken) external {
    _harvest(_stakeToken);
  }

  function _harvest(address _stakeToken) internal {
    _harvestFromMasterBarista(IERC20(_stakeToken));
  }

  function masterBaristaCall(
    address, /*stakeToken*/
    address, /*userAddr*/
    uint256, /*reward*/
    uint256 /*lastRewardBlock*/
  ) external override {
    emit OnBeforeLock();
  }
}
