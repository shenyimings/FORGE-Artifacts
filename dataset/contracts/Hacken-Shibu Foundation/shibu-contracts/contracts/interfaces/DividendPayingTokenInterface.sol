// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface DividendPayingTokenInterface {
  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function dividendOf(address _owner) external view returns(uint256);


  /// @notice Withdraws the BNB distributed to the sender.
  /// @dev SHOULD transfer `dividendOf(msg.sender)` wei to `msg.sender`, and `dividendOf(msg.sender)` SHOULD be 0 after the transfer.
  ///  MUST emit a `DividendWithdrawn` event if the amount of BNB transferred is greater than 0.
  function withdrawDividend() external;

  /// @dev This event MUST emit when BNB is distributed to token holders.
  /// @param from The address which sends BNB to this contract.
  /// @param weiAmount The amount of distributed BNB in wei.
  event DividendsDistributed(
    address indexed from,
    uint256 weiAmount
  );

  /// @dev This event MUST emit when an address withdraws their dividend.
  /// @param to The address which withdraws BNB from this contract.
  /// @param weiAmount The amount of withdrawn BNB in wei.
  event DividendWithdrawn(
    address indexed to,
    uint256 weiAmount
  );
}
