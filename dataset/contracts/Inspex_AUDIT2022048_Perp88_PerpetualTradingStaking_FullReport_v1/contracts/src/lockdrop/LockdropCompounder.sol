// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ILockdrop } from "./interfaces/ILockdrop.sol";
import { IStaking } from "../staking/interfaces/IStaking.sol";

contract LockdropCompounder is OwnableUpgradeable, ReentrancyGuardUpgradeable {
  // --- Libraries ---
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // --- Events ---
  event LogCompound(address indexed user, uint256 amount);

  // --- Custom Errors ---
  error LockdropCompounder_NoESP88();

  // --- States ---
  address public esp88Token;
  address public dragonStaking;
  address public revenueToken;

  function initialize(
    address esp88Token_,
    address dragonStaking_,
    address revenueToken_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    esp88Token = esp88Token_;
    dragonStaking = dragonStaking_;
    revenueToken = revenueToken_;
  }

  function _claimAllFor(address[] memory lockdrops, address user) internal {
    uint256 length = lockdrops.length;
    for (uint256 i = 0; i < length; ) {
      ILockdrop(lockdrops[i]).claimAllRewardsFor(user, address(this));
      unchecked {
        ++i;
      }
    }
  }

  function claimAll(address[] memory lockdrops, address user) external {
    uint256 length = lockdrops.length;
    for (uint256 i = 0; i < length; ) {
      ILockdrop(lockdrops[i]).claimAllRewards(user);
      unchecked {
        ++i;
      }
    }
  }

  /// @dev Users can compound their EsP88 reward into dragon staking.
  /// @param lockdrops array of lockdrop addresses
  function compound(address[] memory lockdrops) external nonReentrant {
    uint256 esp88AmountBefore = IERC20Upgradeable(esp88Token).balanceOf(
      address(this)
    );
    uint256 revenueTokenAmountBefore = IERC20Upgradeable(revenueToken)
      .balanceOf(address(this));
    _claimAllFor(lockdrops, msg.sender);
    uint256 esp88AmountAfter = IERC20Upgradeable(esp88Token).balanceOf(
      address(this)
    ) - esp88AmountBefore;
    IStaking(dragonStaking).deposit(
      address(this),
      esp88Token,
      esp88AmountAfter
    );
    IERC20Upgradeable(revenueToken).safeTransfer(
      msg.sender,
      IERC20Upgradeable(revenueToken).balanceOf(address(this)) -
        revenueTokenAmountBefore
    );
    emit LogCompound(msg.sender, esp88AmountAfter);
  }

  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
