// SPDX-License-Identifier: UNLICENSED
// IAnchorAccount.sol: Interface for wrapping around Anchor deposit subcontracts
pragma solidity >=0.7.0 <0.8.0;

interface IAnchorAccount {
  function initDepositStable(uint256 amount) external;

  function finishDepositStable() external;

  function initRedeemStable(uint256 amount) external;

  function finishRedeemStable() external;

  function transferOwnership(address newOwner) external;

  function reportFailure() external;
}
