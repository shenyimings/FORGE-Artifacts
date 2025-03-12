// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import {IGeodeModule} from "./modules/IGeodeModule.sol";
import {IStakeModule} from "./modules/IStakeModule.sol";

interface IPortal is IStakeModule, IGeodeModule {
  function pausegETH() external;

  function unpausegETH() external;

  function pushUpgrade(uint256 packageType) external returns (bytes memory versionName);

  function releasePrisoned(uint256 operatorId) external;

  function setGovernanceFee(uint256 newFee) external;
}
