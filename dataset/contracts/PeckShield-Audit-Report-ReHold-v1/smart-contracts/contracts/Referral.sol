// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./interfaces/IReferral.sol";
import "./interfaces/IVault.sol";

import "./libraries/math.sol";

contract Referral is AccessControl, IReferral {
  bool public enabled;
  bool public enabledNew;

  uint32 public revShareFee; // 1e8 = 1%

  address public immutable USDT;

  mapping(address => address) public users; // user -> inviter
  mapping(address => Inviter) public inviters;

  IVault public vault;

  constructor(IVault _vault, address _USDT) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    vault = _vault;
    USDT = _USDT;
    enabled = true;
    enabledNew = true;
  }

  function claim() public {
    Inviter storage inviter = inviters[msg.sender];
    require(inviter.unclaimedBalance > 0, "Nothing to claim");

    uint256 unclaimedBalance = inviter.unclaimedBalance;
    inviter.unclaimedBalance = 0;
    inviter.claimedBalance += unclaimedBalance;

    vault.withdrawTokens(USDT, msg.sender, unclaimedBalance);

    emit Claim(msg.sender, unclaimedBalance);
  }

  function earn(
    address user,
    uint256 profitUSDT,
    address inviterAddress
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    if (!enabled || revShareFee == 0) return;

    _earn(user, profitUSDT, 0, inviterAddress);
  }

  function updateRevShareFee(uint32 percent) public onlyRole(DEFAULT_ADMIN_ROLE) {
    revShareFee = percent;
  }

  function _earn(
    address user,
    uint256 profit,
    uint8 level,
    address inviterAddress
  ) private {
    address parentInviter = users[user];

    if (parentInviter == address(this)) return; //contract is the default inviter
    if (user == inviterAddress) {
      users[user] = address(this); //deny invite yourself
      return;
    }

    if (parentInviter == address(0x0)) {
      if (!enabledNew) return; //disable for new referrals
      if (inviterAddress == address(0x0)) {
        users[user] = address(this); //if the first time without inviter, next time too
        return;
      }

      parentInviter = inviterAddress;
      users[user] = parentInviter;
    }

    Inviter storage parent = inviters[parentInviter];

    if (parent.level < level) return;

    uint32 _revShareFee = parent.revShareFee > 0 ? parent.revShareFee : revShareFee;
    uint256 revShareAmount = Math.percent(profit, _revShareFee);
    parent.unclaimedBalance += revShareAmount;

    emit Earning(parentInviter, user, revShareAmount, level);

    //recursive
    _earn(parentInviter, revShareAmount, ++level, address(0x0));
  }

  function updateInviter(address inviter, InviterProps memory info) public onlyRole(DEFAULT_ADMIN_ROLE) {
    Inviter storage inviterInfo = inviters[inviter];
    inviterInfo.level = info.level;
    inviterInfo.revShareFee = info.revShareFee;
  }

  function enable() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabled = true;
  }

  function disable() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabled = false;
  }

  function enableNew() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabledNew = true;
  }

  function disableNew() public onlyRole(DEFAULT_ADMIN_ROLE) {
    enabledNew = false;
  }

  function updateVault(IVault _vault) public onlyRole(DEFAULT_ADMIN_ROLE) {
    vault = _vault;
  }
}
