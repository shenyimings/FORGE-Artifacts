// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IStaking } from "./interfaces/IStaking.sol";

contract Compounder is OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error Compounder_InconsistentLength();

  address public dp;
  address public destinationCompundPool;
  address[] public tokens;
  mapping(address => bool) public isCompoundableTokens;

  function initialize(
    address dp_,
    address destinationCompundPool_,
    address[] memory tokens_,
    bool[] memory isCompoundTokens_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    dp = dp_;
    destinationCompundPool = destinationCompundPool_;
    addToken(tokens_, isCompoundTokens_);
  }

  function addToken(
    address[] memory newTokens,
    bool[] memory newIsCompoundTokens
  ) public onlyOwner {
    uint256 length = newTokens.length;
    if (length != newIsCompoundTokens.length)
      revert Compounder_InconsistentLength();

    for (uint256 i = 0; i < length; ) {
      tokens.push(newTokens[i]);
      setCompoundToken(tokens[i], newIsCompoundTokens[i]);

      unchecked {
        ++i;
      }
    }
  }

  function removeToken(address token) public onlyOwner {
    uint256 length = tokens.length;

    for (uint256 i = 0; i < length; ) {
      if (tokens[i] == token) {
        tokens[i] = tokens[tokens.length - 1];
        tokens.pop();

        setCompoundToken(token, false);
        break;
      }

      unchecked {
        ++i;
      }
    }
  }

  function setCompoundToken(address token, bool isCompoundToken)
    public
    onlyOwner
  {
    isCompoundableTokens[token] = isCompoundToken;

    if (isCompoundToken)
      IERC20Upgradeable(token).approve(
        destinationCompundPool,
        type(uint256).max
      );
  }

  function claimAll(address[] memory pools, address[][] memory rewarders)
    external
  {
    _claimAll(pools, rewarders);
    _compoundOrTransfer(false);
  }

  function compound(address[] memory pools, address[][] memory rewarders)
    external
  {
    _claimAll(pools, rewarders);
    _compoundOrTransfer(true);
  }

  function _compoundOrTransfer(bool isCompound) internal {
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      uint256 amount = IERC20Upgradeable(tokens[i]).balanceOf(address(this));
      if (amount > 0) {
        // always compound dragon point
        if (
          tokens[i] == dp || (isCompound && isCompoundableTokens[tokens[i]])
        ) {
          IStaking(destinationCompundPool).deposit(
            msg.sender,
            tokens[i],
            amount
          );
        } else {
          IERC20Upgradeable(tokens[i]).safeTransfer(msg.sender, amount);
        }
      }

      unchecked {
        ++i;
      }
    }
  }

  function _claimAll(address[] memory pools, address[][] memory rewarders)
    internal
  {
    uint256 length = pools.length;
    for (uint256 i = 0; i < length; ) {
      IStaking(pools[i]).harvestToCompounder(msg.sender, rewarders[i]);

      unchecked {
        ++i;
      }
    }
  }

  receive() external payable {}

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
