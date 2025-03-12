// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../proxy/ControllableV3.sol";
import "../vault/ERC4626Upgradeable.sol";

contract MockVaultSimple is ERC4626Upgradeable, ControllableV3 {
  using SafeERC20 for IERC20;

  uint constant public FEE_DENOMINATOR = 100;


  function init(
    address controller_,
    IERC20 _asset,
    string memory _name,
    string memory _symbol
  ) external initializer {
    __ERC4626_init(_asset, _name, _symbol);
    __Controllable_init(controller_);
  }

  function totalAssets() public view override returns (uint) {
    return _asset.balanceOf(address(this));
  }

}
