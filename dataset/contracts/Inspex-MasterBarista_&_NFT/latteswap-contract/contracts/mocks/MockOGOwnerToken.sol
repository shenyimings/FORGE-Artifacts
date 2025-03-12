// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../nft/interfaces/IOGOwnerToken.sol";

contract MockOGOwnerToken is IOGOwnerToken, ERC20, Ownable {
  /// @dev just reserve for future use
  address timelock;

  mapping(address => bool) public okHolders;

  modifier onlyTimelock() {
    require(timelock == msg.sender, "OGOwnerToken::onlyTimelock:: msg.sender not timelock");
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _timelock
  ) public ERC20(_name, _symbol) {
    timelock = _timelock;
  }

  function setOkHolders(address[] memory _okHolders, bool _isOk) public override onlyOwner {
    for (uint256 idx = 0; idx < _okHolders.length; idx++) {
      okHolders[_okHolders[idx]] = _isOk;
    }
  }

  function mint(address to, uint256 amount) public override onlyOwner {
    require(okHolders[to], "OGOwnerToken::mint:: unapproved holder");
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public override onlyOwner {
    require(okHolders[from], "OGOwnerToken::burn:: unapproved holder");
    _burn(from, amount);
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    // allow the caller to transfer back to a destination
    require(okHolders[msg.sender], "OGOwnerToken::transfer:: unapproved holder on msg.sender");
    require(okHolders[to], "OGOwnerToken::transfer:: unapproved holder on to");
    _transfer(msg.sender, to, amount);
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public override returns (bool) {
    // allow the caller to transfer back to a destination
    require(okHolders[from], "OGOwnerToken::transferFrom:: unapproved holder in from");
    require(okHolders[to], "OGOwnerToken::transferFrom:: unapproved holder in to");
    _transfer(from, to, amount);
    _approve(from, _msgSender(), allowance(from, _msgSender()).sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }
}
