// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../../contracts/v0.8.16/interfaces/IFeeModel.sol";
import "../../../../lib/mock-contract/contracts/MockContract.sol";

contract MockGovLPVault is MockContract, Ownable {
  address public rewardsDistribution;
  address public rewardsToken;
  IERC20 public stakingToken;
  bool public isGovLpVault;
  address public controller;

  MockGovLPVault public immutable masterContract;

  constructor() {
    masterContract = this;
  }

  function masterContractOwner() external view returns (address) {
    return masterContract.owner();
  }

  function initialize(
    address _rewardsDistribution,
    address _rewardsToken,
    address _stakingToken,
    address _controller
  ) public {
    rewardsToken = _rewardsToken;
    stakingToken = IERC20(_stakingToken);
    rewardsDistribution = _rewardsDistribution;
    controller = _controller;
    isGovLpVault = true;
  }
}
