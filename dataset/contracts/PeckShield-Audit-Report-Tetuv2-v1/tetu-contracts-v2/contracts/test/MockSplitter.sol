// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../interfaces/ISplitter.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/ITetuVaultV2.sol";
import "../proxy/ControllableV3.sol";

contract MockSplitter is ISplitter, ControllableV3 {

  address public override asset;
  address public override vault;
  uint public slippage;

  function init(address controller_, address _asset, address _vault) external initializer override {
    __Controllable_init(controller_);
    asset = _asset;
    vault = _vault;
  }

  function setSlippage(uint value) external {
    slippage = value;
  }

  function withdrawAllToVault() external override {
    withdrawToVault(IERC20(asset).balanceOf(address(this)));
  }

  function withdrawToVault(uint256 amount) public override {
    uint toSend = amount - amount * slippage / 1000;
    if (slippage != 0) {
      IERC20(asset).transfer(controller(), amount - toSend);
    }
    IERC20(asset).transfer(vault, toSend);
  }

  function doHardWork() external override {
    // noop
  }

  function investAll() external override {
    // noop
  }

  function totalAssets() external view override returns (uint256) {
    return IERC20(asset).balanceOf(address(this));
  }

  function isHardWorking() external pure override returns (bool) {
    return false;
  }

  function lost(uint amount) external {
    IERC20(asset).transfer(msg.sender, amount);
  }

  function coverLoss(uint amount) external {
    ITetuVaultV2(vault).coverLoss(amount);
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_SPLITTER || super.supportsInterface(interfaceId);
  }

}
