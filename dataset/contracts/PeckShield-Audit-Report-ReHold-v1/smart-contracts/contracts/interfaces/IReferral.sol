// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IReferral is IAccessControl {
  event Earning(address indexed inviter, address indexed user, uint256 indexed amount, uint8 level);
  event Claim(address indexed user, uint256 amount);

  struct Inviter {
    uint32 revShareFee; //override common rev share fee
    uint8 level;
    uint256 unclaimedBalance;
    uint256 claimedBalance;
  }

  struct InviterProps {
    uint32 revShareFee; //override common rev share fee
    uint8 level;
  }

  function claim() external;

  function earn(address user, uint256 profitUSDT, address inviter) external;

  function updateRevShareFee(uint32 percent) external;

  function updateInviter(address inviter, InviterProps memory info) external;
}
