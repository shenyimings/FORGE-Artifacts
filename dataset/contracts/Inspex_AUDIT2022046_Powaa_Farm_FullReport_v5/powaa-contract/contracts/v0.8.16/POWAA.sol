// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract POWAA is Context, Ownable, ERC20("POWAA token", "POWAA") {
  /// @dev Custom Errors
  error POWAA_MaxTotalSupplyExceeded();

  /// @dev Variables
  uint256 private immutable _maxTotalSupply;

  constructor(uint256 maxTotalSupply_) {
    _maxTotalSupply = maxTotalSupply_;
  }

  function maxTotalSupply() public view virtual returns (uint256) {
    return _maxTotalSupply;
  }

  function mint(address to, uint256 amount) external onlyOwner returns (bool) {
    if (ERC20.totalSupply() + amount > _maxTotalSupply) {
      revert POWAA_MaxTotalSupplyExceeded();
    }
    _mint(to, amount);
    return true;
  }
}
