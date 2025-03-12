// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IRewarder.sol";
import "./interfaces/IStaking.sol";
import "../tokens/DragonPoint.sol";

contract DragonStaking is IStaking, OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error DragonStaking_UnknownStakingToken();
  error DragonStaking_InsufficientTokenAmount();
  error DragonStaking_InvalidTokenAmount();
  error DragonStaking_NotRewarder();
  error DragonStaking_NotCompounder();
  error DragonStaking_DragonPointWithdrawForbid();

  mapping(address => mapping(address => uint256)) public userTokenAmount;
  mapping(address => bool) public isRewarder;
  mapping(address => bool) public isStakingToken;
  mapping(address => address[]) public stakingTokenRewarders;
  mapping(address => address[]) public rewarderStakingTokens;

  address public compounder;

  DragonPoint public dp;
  IRewarder public dragonPointRewarder;

  event LogDeposit(
    address indexed caller,
    address indexed user,
    address token,
    uint256 amount
  );
  event LogWithdraw(address indexed caller, address token, uint256 amount);

  function initialize(address dp_) external initializer {
    OwnableUpgradeable.__Ownable_init();

    dp = DragonPoint(dp_);
  }

  function addStakingToken(address newToken, address[] memory newRewarders)
    external
    onlyOwner
  {
    uint256 length = newRewarders.length;
    for (uint256 i = 0; i < length; ) {
      _updatePool(newToken, newRewarders[i]);

      unchecked {
        ++i;
      }
    }
  }

  function addRewarder(address newRewarder, address[] memory newTokens)
    external
    onlyOwner
  {
    uint256 length = newTokens.length;
    for (uint256 i = 0; i < length; ) {
      _updatePool(newTokens[i], newRewarder);

      unchecked {
        ++i;
      }
    }
  }

  function _updatePool(address newToken, address newRewarder) internal {
    stakingTokenRewarders[newToken].push(newRewarder);
    rewarderStakingTokens[newRewarder].push(newToken);
    isStakingToken[newToken] = true;
    if (!isRewarder[newRewarder]) {
      isRewarder[newRewarder] = true;
    }
  }

  function setCompounder(address compounder_) external onlyOwner {
    compounder = compounder_;
  }

  function deposit(
    address to,
    address token,
    uint256 amount
  ) external {
    _deposit(to, token, amount);
  }

  function _deposit(
    address to,
    address token,
    uint256 amount
  ) internal {
    if (!isStakingToken[token]) revert DragonStaking_UnknownStakingToken();

    uint256 length = stakingTokenRewarders[token].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = stakingTokenRewarders[token][i];

      IRewarder(rewarder).onDeposit(to, amount);

      unchecked {
        ++i;
      }
    }

    userTokenAmount[token][to] += amount;
    IERC20Upgradeable(token).safeTransferFrom(
      msg.sender,
      address(this),
      amount
    );

    emit LogDeposit(msg.sender, to, token, amount);
  }

  function getUserTokenAmount(address token, address sender)
    external
    view
    returns (uint256)
  {
    return userTokenAmount[token][sender];
  }

  function getStakingTokenRewarders(address token)
    external
    view
    returns (address[] memory)
  {
    return stakingTokenRewarders[token];
  }

  function withdraw(address token, uint256 amount) external {
    if (token == address(dp)) revert DragonStaking_DragonPointWithdrawForbid();
    if (amount == 0) revert DragonStaking_InvalidTokenAmount();

    // Clear all of user dragon point
    dragonPointRewarder.onHarvest(msg.sender, msg.sender);
    _withdraw(address(dp), userTokenAmount[address(dp)][msg.sender]);

    // Withdraw the actual token, while we note down the share before/after (which already exclude Dragon Point)
    uint256 shareBefore = _calculateShare(
      address(dragonPointRewarder),
      msg.sender
    );
    _withdraw(token, amount);
    uint256 shareAfter = _calculateShare(
      address(dragonPointRewarder),
      msg.sender
    );

    // Find the burn amount
    uint256 dpBalance = dp.balanceOf(msg.sender);
    uint256 targetDpBalance = (dpBalance * shareAfter) / shareBefore;

    // Burn from user, transfer the rest to here, and got depositted
    dp.burn(msg.sender, dpBalance - targetDpBalance);
    _deposit(msg.sender, address(dp), dp.balanceOf(msg.sender));

    emit LogWithdraw(msg.sender, token, amount);
  }

  function _withdraw(address token, uint256 amount) internal {
    if (!isStakingToken[token]) revert DragonStaking_UnknownStakingToken();
    if (userTokenAmount[token][msg.sender] < amount)
      revert DragonStaking_InsufficientTokenAmount();

    uint256 length = stakingTokenRewarders[token].length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = stakingTokenRewarders[token][i];

      IRewarder(rewarder).onWithdraw(msg.sender, amount);

      unchecked {
        ++i;
      }
    }
    userTokenAmount[token][msg.sender] -= amount;
    IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
    emit LogWithdraw(msg.sender, token, amount);
  }

  function harvest(address[] memory rewarders) external {
    _harvestFor(msg.sender, msg.sender, rewarders);
  }

  function harvestToCompounder(address user, address[] memory rewarders)
    external
  {
    if (compounder != msg.sender) revert DragonStaking_NotCompounder();
    _harvestFor(user, compounder, rewarders);
  }

  function _harvestFor(
    address user,
    address receiver,
    address[] memory rewarders
  ) internal {
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (!isRewarder[rewarders[i]]) {
        revert DragonStaking_NotRewarder();
      }

      IRewarder(rewarders[i]).onHarvest(user, receiver);

      unchecked {
        ++i;
      }
    }
  }

  function calculateShare(address rewarder, address user)
    external
    view
    returns (uint256)
  {
    return _calculateShare(rewarder, user);
  }

  function _calculateShare(address rewarder, address user)
    internal
    view
    returns (uint256)
  {
    address[] memory tokens = rewarderStakingTokens[rewarder];
    uint256 share = 0;
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      share += userTokenAmount[tokens[i]][user];

      unchecked {
        ++i;
      }
    }
    return share;
  }

  function calculateTotalShare(address rewarder)
    external
    view
    returns (uint256)
  {
    address[] memory tokens = rewarderStakingTokens[rewarder];
    uint256 totalShare = 0;
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      totalShare += IERC20Upgradeable(tokens[i]).balanceOf(address(this));

      unchecked {
        ++i;
      }
    }
    return totalShare;
  }

  function setDragonPointRewarder(address rewarder) external onlyOwner {
    dragonPointRewarder = IRewarder(rewarder);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
