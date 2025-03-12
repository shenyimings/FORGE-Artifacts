// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IStaking } from "../../staking/interfaces/IStaking.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILockdropGateway {
  function claimAllStakingContractRewards(
    address[] memory lockdropList,
    address user
  ) external;

  function claimAllP88(address[] memory lockdropList, address user) external;

  function withdrawAllAndStakePLP(address[] memory lockdropList, address user)
    external;
}
