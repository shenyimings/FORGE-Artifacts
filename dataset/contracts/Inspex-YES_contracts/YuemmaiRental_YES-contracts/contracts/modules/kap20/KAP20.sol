// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IKAP20.sol";
import "./interfaces/IKToken.sol";

import "../pause/Pausable.sol";
import "../committee/KAP20Committee.sol";
import "../admin/Authorization.sol";
import "../kyc/KYCHandler.sol";
import "../blacklist/Blacklist.sol";

contract KAP20 is IKAP20, IKToken, Pausable, KAP20Committee, Authorization, KYCHandler, Blacklist {
  
  mapping(address => uint256) _balances;

  mapping(address => mapping(address => uint256)) internal _allowance;

  uint256 public override totalSupply;

  string public override name;
  string public override symbol;
  uint8 public override decimals;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    address committee_,
    address adminRouter_,
    address kyc_, 
    uint256 acceptedKycLevel_
  ) KAP20Committee(committee_) Authorization(adminRouter_) KYCHandler(kyc_, acceptedKycLevel_) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
  }

  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public virtual override whenNotPaused notInBlacklist(msg.sender) returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowance[owner][spender];
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override whenNotPaused notInBlacklist(sender) returns (bool) {
    _transfer(sender, recipient, amount);

    uint256 currentAllowance = _allowance[sender][msg.sender];
    require(currentAllowance >= amount, "KAP20: transfer amount exceeds allowance");
    unchecked { _approve(sender, msg.sender, currentAllowance - amount); }

    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(msg.sender, spender, _allowance[msg.sender][spender] + addedValue);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowance[msg.sender][spender];
    require(currentAllowance >= subtractedValue, "KAP20: decreased allowance below zero");
    unchecked { _approve(msg.sender, spender, currentAllowance - subtractedValue); }

    return true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual {
    require(sender != address(0), "KAP20: transfer from the zero address");
    require(recipient != address(0), "KAP20: transfer to the zero address");

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "KAP20: transfer amount exceeds balance");
    unchecked { _balances[sender] = senderBalance - amount; }
    _balances[recipient] += amount;

    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: mint to the zero address");

    totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "KAP20: burn amount exceeds balance");
    unchecked { _balances[account] = accountBalance - amount; }
    totalSupply -= amount;

    emit Transfer(account, address(0), amount);
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "KAP20: approve from the zero address");
    require(spender != address(0), "KAP20: approve to the zero address");

    _allowance[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function adminTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override onlyCommittee returns (bool) {
    require(_balances[sender] >= amount, "KAP20: transfer amount exceed balance");
    require(recipient != address(0), "KAP20: transfer to zero address");
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(sender, recipient, amount);

    return true;
  }

  function internalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdmin returns (bool) {
    require(
      kyc.kycsLevel(sender) >= acceptedKycLevel && kyc.kycsLevel(recipient) >= acceptedKycLevel,
      "Only internal purpose"
    );

    _transfer(sender, recipient, amount);
    return true;
  }

  function externalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdmin returns (bool) {
    require(kyc.kycsLevel(sender) >= acceptedKycLevel, "Only internal purpose");

    _transfer(sender, recipient, amount);
    return true;
  }

  function activateOnlyKycAddress() public override onlyCommittee {
    _activateOnlyKycAddress();
  }

  function setKYC(address _kyc) public override onlyCommittee {
    _setKYC(IKYCBitkubChain(_kyc));
  }

  function setAcceptedKycLevel(uint256 _kycLevel) public override onlyCommittee {
    _setAcceptedKycLevel(_kycLevel);
  }

  function setCommittee(address _committee) external override onlyCommittee {
    _setCommittee(_committee);
  }

  function pause() external override onlyCommittee {
    _pause();
  }

  function unpause() external override onlyCommittee {
    _unpause();
  }

  function addBlacklist(address account) external override onlyCommittee {
    _addBlacklist(account);
  }

  function revokeBlacklist(address account) external override onlyCommittee {
    _revokeBlacklist(account);
  }

}