// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IStaking } from "../../staking/interfaces/IStaking.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockErc20 } from "../mocks/MockERC20.sol";
import { MockWNative } from "../base/BaseTest.sol";
import { IWNative } from "../../interfaces/IWNative.sol";

using SafeERC20 for IERC20;

contract MockPLPStaking is IStaking {
  mapping(address => mapping(address => uint256)) public userTokenAmount;

  address internal plpTokenAddress;
  MockWNative internal revenueToken;
  address internal esp88TokenAddress;
  address internal mockRewarder;

  uint256 internal revenueRewardAmount;
  uint256 internal esp88RewardLastReward;
  uint256 internal rewardPerSec;

  constructor(
    address _plpTokenAddress,
    MockWNative _revenueToken,
    address _esp88TokenAddress
  ) {
    plpTokenAddress = _plpTokenAddress;
    revenueToken = _revenueToken;
    esp88TokenAddress = _esp88TokenAddress;
    mockRewarder = address(1);
    rewardPerSec = 1 ether;
    esp88RewardLastReward = block.timestamp;
  }

  function deposit(
    address to,
    address token,
    uint256 amount
  ) external {
    IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    userTokenAmount[token][to] += amount;
  }

  function withdraw(address token, uint256 amount) external {
    // IERC20(token).approve(msg.sender, amount);
    IERC20(token).safeTransfer(msg.sender, amount);
  }

  function getUserTokenAmount(address token, address sender)
    external
    view
    returns (uint256)
  {
    return IERC20(plpTokenAddress).balanceOf(address(this));
  }

  function getStakingTokenRewarders(address token)
    external
    view
    returns (address[] memory)
  {
    address[] memory rewarderList = new address[](1);
    rewarderList[0] = mockRewarder;

    return rewarderList;
  }

  function harvest(address[] memory rewarders) external {
    uint256 esp88RewardAmount = (block.timestamp - esp88RewardLastReward) *
      rewardPerSec;

    MockErc20(esp88TokenAddress).mint(msg.sender, esp88RewardAmount);

    // unwrap
    IWNative(revenueToken).withdraw(revenueRewardAmount);
    // transfer native token
    payable(msg.sender).transfer(revenueRewardAmount);

    // update state
    revenueRewardAmount = 0;
    esp88RewardLastReward = block.timestamp;
  }

  function feedRevenueReward(uint256 tokenAmount) external {
    revenueToken.transferFrom(msg.sender, address(this), tokenAmount);

    revenueRewardAmount += tokenAmount;
  }

  function harvestToCompounder(address user, address[] memory rewarders)
    external
  {}

  function calculateTotalShare(address rewarder)
    external
    view
    returns (uint256)
  {}

  function calculateShare(address rewarder, address user)
    external
    view
    returns (uint256)
  {}

  function isRewarder(address rewarder) external view returns (bool) {}

  receive() external payable {}
}
