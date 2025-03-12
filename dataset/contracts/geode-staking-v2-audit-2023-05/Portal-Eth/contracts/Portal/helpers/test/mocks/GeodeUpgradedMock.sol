// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {GeodeModuleMock} from "./GeodeModuleMock.sol";
import {GeodeModuleLib} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";

contract GeodeUpgradedMock is GeodeModuleMock {
  using GeodeModuleLib for GeodeModuleLib.DualGovernance;

  uint256 dumbStorageSlot;

  function initialize2(uint value) external reinitializer(2) {
    dumbStorageSlot = value;
  }

  function setDumb(uint value) external {
    dumbStorageSlot = value;
  }

  function getDumb() external view returns (uint256) {
    return dumbStorageSlot;
  }

  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) public virtual override returns (uint256 id) {
    require(0 == 1, "This function is overriden!");
    return 0;
  }

  uint256[49] private __gap;
}
