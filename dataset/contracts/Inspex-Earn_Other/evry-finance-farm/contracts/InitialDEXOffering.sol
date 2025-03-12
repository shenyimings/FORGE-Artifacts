//contracts/InitialDEXOffering.sol
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract InitialDEXOffering is Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint256 private constant RATIO_PRECISION = 1e18;

  /// @dev constructor
  uint256 public startBlock;
  uint256 public endBlock;

  IERC20 public offeringToken;
  IERC20 public spendingToken;
  uint256 public tokenRatio;
  uint256 public minSpendingPerTx;
  uint256 public maxSpendingPerTx;

  uint256 public offered;

  event Buy(address indexed user, uint256 spendingTokenAmount, uint256 offeringTokenAmount);
  event RecoveryOfferingToken(address indexed target, uint256 offeringTokenAmount);
  event ClaimSpendingToken(address indexed target, uint256 spendingTokenAmount);

  constructor(
    IERC20 _offeringToken,
    IERC20 _spendingToken,
    uint256 _tokenRatio,
    uint256 _startBlock,
    uint256 _endBlock,
    uint256 _minSpendingPerTx,
    uint256 _maxSpendingPerTx,
    address _admin
  ) {
    offeringToken = _offeringToken;
    spendingToken = _spendingToken;
    tokenRatio = _tokenRatio;
    startBlock = _startBlock;
    endBlock = _endBlock;
    minSpendingPerTx = _minSpendingPerTx;
    maxSpendingPerTx = _maxSpendingPerTx;

    require(_offeringToken != _spendingToken, "tokens must be be different");

    transferOwnership(_admin);
  }

  function buy(uint256 _spendingTokenAmount) external nonReentrant {
    require(block.number >= startBlock, "too early to buy");
    require(block.number < endBlock, "too late to buy");
    require(_spendingTokenAmount <= maxSpendingPerTx, "amount is exceed limit");
    require(_spendingTokenAmount >= minSpendingPerTx, "amount is lower than limit");
    require(offeringToken.balanceOf(address(this)) > 0, "it is sold out");

    uint256 actualSpending = _spendingTokenAmount;
    uint256 actualOffering = _spendingTokenAmount.mul(tokenRatio).div(RATIO_PRECISION);
    uint256 remainingOffering = offeringToken.balanceOf(address(this));
    if (actualOffering > remainingOffering) {
      actualOffering = remainingOffering;
      actualSpending = actualOffering.div(tokenRatio).mul(RATIO_PRECISION);
    }

    uint256 preBalance = spendingToken.balanceOf(address(this));
    spendingToken.safeTransferFrom(msg.sender, address(this), actualSpending);
    uint256 postBalance = spendingToken.balanceOf(address(this));
    require(postBalance.sub(preBalance) == actualSpending, "not support deflationary token");

    offered = offered.add(actualOffering);
    offeringToken.safeTransfer(msg.sender, actualOffering);

    emit Buy(msg.sender, actualSpending, actualOffering);
  }

  function offeringCap() external view returns (uint256) {
    return offered.add(offeringToken.balanceOf(address(this)));
  }

  /// @notice Owner method to get back all unsold offering token - only can be done after end period
  function recoveryOfferingToken(address _for) external onlyOwner {
    require(block.number > endBlock, "too early to recovery");

    uint256 remainingOfferingToken = offeringToken.balanceOf(address(this));
    offeringToken.safeTransfer(_for, remainingOfferingToken);
    emit RecoveryOfferingToken(_for, remainingOfferingToken);
  }

  /// @notice Owner method to get all the Spending token - any time
  function claimSpendingToken(address _for) external onlyOwner {
    uint256 balance = spendingToken.balanceOf(address(this));
    spendingToken.safeTransfer(_for, balance);
    emit ClaimSpendingToken(_for, balance);
  }
}
