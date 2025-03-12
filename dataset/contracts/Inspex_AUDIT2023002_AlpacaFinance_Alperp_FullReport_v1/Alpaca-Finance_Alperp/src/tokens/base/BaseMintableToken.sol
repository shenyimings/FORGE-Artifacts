// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/

pragma solidity 0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { MintableTokenInterface } from "../../interfaces/MintableTokenInterface.sol";

contract BaseMintableToken is Ownable, ERC20, MintableTokenInterface {
  error BaseMintableToken_NotMinter();
  error BaseMintableToken_MintExceedMaxSupply();
  error BaseMintableToken_ExceedMaxSupplyCap();

  uint8 private _decimals;
  uint256 public maxSupply;
  uint256 public maxSupplyCap;
  mapping(address => bool) public isMinter;

  event SetMinter(address minter, bool prevAllow, bool newAllow);
  event SetMaxSupply(uint256 oldMaxSupply, uint256 newMaxSupply);

  constructor(
    string memory name,
    string memory symbol,
    uint8 __decimals,
    uint256 maxSupply_,
    uint256 maxSupplyCap_
  ) ERC20(name, symbol) {
    _decimals = __decimals;
    maxSupply = maxSupply_;
    maxSupplyCap = maxSupplyCap_;
  }

  modifier onlyMinter() {
    if (!isMinter[msg.sender]) revert BaseMintableToken_NotMinter();
    _;
  }

  function setMinter(address minter, bool allow) external override onlyOwner {
    emit SetMinter(minter, isMinter[minter], allow);
    isMinter[minter] = allow;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  function mint(address to, uint256 amount) public override onlyMinter {
    if (totalSupply() + amount > maxSupply)
      revert BaseMintableToken_MintExceedMaxSupply();
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public override onlyMinter {
    _burn(from, amount);
  }

  function setMaxSupply(uint256 newMaxSupply_) external onlyOwner {
    if (newMaxSupply_ > maxSupplyCap)
      revert BaseMintableToken_ExceedMaxSupplyCap();
    uint256 oldMaxSupply = maxSupplyCap;
    maxSupply = newMaxSupply_;

    emit SetMaxSupply(oldMaxSupply, newMaxSupply_);
  }
}
