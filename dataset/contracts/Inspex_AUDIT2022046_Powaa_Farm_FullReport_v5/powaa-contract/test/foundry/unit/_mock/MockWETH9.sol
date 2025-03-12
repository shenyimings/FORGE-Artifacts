// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "./MockERC20.sol";
import "../../../../lib/solmate/src/utils/SafeTransferLib.sol";

contract MockWETH9 is MockERC20 {
  using SafeTransferLib for address;

  /// @notice Deposit ether to get wrapped ether
  function deposit() external payable {}

  /// @notice Withdraw wrapped ether to get ether
  function withdraw(uint256 _amount) external {
    _burn(msg.sender, _amount);
    msg.sender.safeTransferETH(_amount);
  }
}
