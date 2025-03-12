// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/IERC4626.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IVeTetu.sol";
import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/ReentrancyGuard.sol";

contract DepositHelper is ReentrancyGuard{
  using SafeERC20 for IERC20;

  address public immutable oneInchRouter;

  constructor(address _oneInchRouter) {
    require(_oneInchRouter != address(0), "WRONG_INPUT");
    oneInchRouter = _oneInchRouter;
  }

  /// @dev Proxy deposit action for keep approves on this contract
  function deposit(address vault, address asset, uint amount) public nonReentrant returns (uint){
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    _approveIfNeeds(asset, amount, vault);
    return IERC4626(vault).deposit(amount, msg.sender);
  }

  /// @dev Convert input token to output token and deposit.
  ///      tokenOut should be vault asset
  function convertAndDeposit(
    bytes memory swapData,
    address tokenIn,
    uint amountIn,
    address vault
  ) external nonReentrant returns (uint){
    IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

    _approveIfNeeds(tokenIn, amountIn, oneInchRouter);
    (bool success,bytes memory result) = oneInchRouter.call(swapData);
    require(success, string(result));

    address asset = address(IERC4626(vault).asset());
    uint balance = IERC20(asset).balanceOf(address(this));

    require(balance != 0, "Zero result balance");
    _approveIfNeeds(asset, balance, vault);
    return IERC4626(vault).deposit(balance, msg.sender);
  }

  /// @dev Withdraw from given vault and convert assets to tokenOut
  ///      tokenIn should be vault asset
  function withdrawAndConvert(
    address vault,
    uint shareAmount,
    bytes memory swapData,
    address tokenOut
  ) external nonReentrant returns (uint){
    _approveIfNeeds(vault, shareAmount, vault);
    uint amountIn = IERC4626(vault).redeem(shareAmount, address(this), msg.sender);

    _approveIfNeeds(address(IERC4626(vault).asset()), amountIn, oneInchRouter);
    (bool success,) = oneInchRouter.call(swapData);
    require(success, "Swap error");

    uint balance = IERC20(tokenOut).balanceOf(address(this));
    require(balance != 0, "Zero result balance");
    IERC20(tokenOut).safeTransfer(msg.sender, balance);
    return balance;
  }

  function createLock(IVeTetu ve, address token, uint value, uint lockDuration) external nonReentrant returns (
    uint tokenId,
    uint lockedAmount,
    uint power,
    uint unlockDate
  ) {
    IERC20(token).safeTransferFrom(msg.sender, address(this), value);
    _approveIfNeeds(token, value, address(ve));
    tokenId = ve.createLockFor(token, value, lockDuration, msg.sender);

    lockedAmount = ve.lockedAmounts(tokenId, token);
    power = ve.balanceOfNFT(tokenId);
    unlockDate = ve.lockedEnd(tokenId);
  }

  function increaseAmount(IVeTetu ve, address token, uint tokenId, uint value) external nonReentrant returns (
    uint lockedAmount,
    uint power,
    uint unlockDate
  ) {
    IERC20(token).safeTransferFrom(msg.sender, address(this), value);
    _approveIfNeeds(token, value, address(ve));
    ve.increaseAmount(token, tokenId, value);

    lockedAmount = ve.lockedAmounts(tokenId, token);
    power = ve.balanceOfNFT(tokenId);
    unlockDate = ve.lockedEnd(tokenId);
  }

  function _approveIfNeeds(address token, uint amount, address spender) internal {
    if (IERC20(token).allowance(address(this), spender) < amount) {
      IERC20(token).safeApprove(spender, 0);
      IERC20(token).safeApprove(spender, type(uint).max);
    }
  }

}
