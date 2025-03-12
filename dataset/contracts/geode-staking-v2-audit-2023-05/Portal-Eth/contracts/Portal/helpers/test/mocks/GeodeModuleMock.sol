// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {GeodeModule} from "../../../modules/GeodeModule/GeodeModule.sol";
import {GeodeModuleLib} from "../../../modules/GeodeModule/libs/GeodeModuleLib.sol";

contract GeodeModuleMock is GeodeModule {
  using GeodeModuleLib for GeodeModuleLib.DualGovernance;

  event return$propose(uint256 id);
  event return$approveProposal(address controller, uint256 _type, bytes name);

  /**
   * @custom:section                           ** INTERNAL **
   */

  function initialize(
    address governance,
    address senate,
    uint256 senateExpiry,
    uint256 packageType,
    bytes calldata initVersionName
  ) external initializer {
    __GeodeModule_init(governance, senate, senateExpiry, packageType, initVersionName);
  }

  /**
   * @custom:section                           ** INTERNAL **
   */
  function isolationMode() external view virtual override returns (bool) {
    return (GEODE.APPROVED_UPGRADE != _getImplementation() ||
      block.timestamp > GEODE.SENATE_EXPIRY);
  }

  function isUpgradeAllowed(address proposedImplementation) public view virtual returns (bool) {
    return GEODE.isUpgradeAllowed(proposedImplementation, _getImplementation());
  }

  /**
   * @custom:section                           ** FOR RETURN STATEMENTS **
   */
  function propose(
    address _CONTROLLER,
    uint256 _TYPE,
    bytes calldata _NAME,
    uint256 duration
  ) public virtual override returns (uint256 id) {
    id = super.propose(_CONTROLLER, _TYPE, _NAME, duration);
    emit return$propose(id);
  }

  function approveProposal(
    uint256 id
  ) public virtual override returns (address _controller, uint256 _type, bytes memory _name) {
    (_controller, _type, _name) = super.approveProposal(id);
    emit return$approveProposal(_controller, _type, _name);
  }

  uint256[50] private __gap;
}
