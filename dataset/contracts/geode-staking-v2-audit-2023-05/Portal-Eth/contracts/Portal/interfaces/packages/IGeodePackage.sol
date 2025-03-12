// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import {IGeodeModule} from "../modules/IGeodeModule.sol";
import {IPortal} from "../IPortal.sol";

interface IGeodePackage is IGeodeModule {
  function initialize(
    uint256 poolId,
    address owner,
    bytes calldata versionName,
    bytes memory data
  ) external;

  function getPortal() external view returns (IPortal);

  function getPoolId() external view returns (uint256);

  function getProposedVersion() external view returns (uint256);

  function pullUpgrade() external;
}
