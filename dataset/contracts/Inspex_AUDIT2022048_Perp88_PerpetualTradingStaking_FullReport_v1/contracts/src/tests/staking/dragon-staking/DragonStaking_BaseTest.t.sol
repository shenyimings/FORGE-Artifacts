// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, DragonStaking, P88, EsP88, DragonPoint, MockErc20, FeedableRewarder, AdHocMintRewarder } from "../../base/BaseTest.sol";

contract DragonStaking_BaseTest is BaseTest {
  P88 internal p88;
  EsP88 internal esP88;
  DragonPoint internal dragonPoint;
  MockErc20 internal revenueToken;
  MockErc20 internal partnerAToken;
  MockErc20 internal partnerBToken;

  DragonStaking internal dragonStaking;

  FeedableRewarder internal revenueRewarder;
  FeedableRewarder internal esP88Rewarder;
  FeedableRewarder internal partnerARewarder;
  FeedableRewarder internal partnerBRewarder;

  AdHocMintRewarder internal dragonPointRewarder;

  function setUp() public virtual {
    vm.startPrank(DAVE);

    p88 = BaseTest.deployP88();
    p88.setMinter(DAVE, true);

    esP88 = BaseTest.deployEsP88();
    esP88.setMinter(DAVE, true);

    dragonPoint = BaseTest.deployDragonPoint();
    dragonPoint.setMinter(DAVE, true);

    revenueToken = BaseTest.deployMockErc20(
      "Protocol Revenue Token",
      "PRT",
      18
    );
    partnerAToken = BaseTest.deployMockErc20("Partner A", "PA", 18);
    partnerBToken = BaseTest.deployMockErc20("Partner B", "PB", 18);

    dragonStaking = BaseTest.deployDragonStaking(address(dragonPoint));
    dragonPoint.setMinter(address(dragonStaking), true);
    dragonPoint.setTransferrer(address(dragonStaking), true);

    revenueRewarder = BaseTest.deployFeedableRewarder(
      "Protocol Revenue Rewarder",
      address(revenueToken),
      address(dragonStaking)
    );
    esP88Rewarder = BaseTest.deployFeedableRewarder(
      "esP88 Rewarder",
      address(esP88),
      address(dragonStaking)
    );
    dragonPointRewarder = BaseTest.deployAdHocMintRewarder(
      "dp Rewarder",
      address(dragonPoint),
      address(dragonStaking)
    );
    partnerARewarder = BaseTest.deployFeedableRewarder(
      "Partner A Rewarder",
      address(partnerAToken),
      address(dragonStaking)
    );
    partnerBRewarder = BaseTest.deployFeedableRewarder(
      "Partner B Rewarder",
      address(partnerBToken),
      address(dragonStaking)
    );

    dragonStaking.setDragonPointRewarder(address(dragonPointRewarder));
    dragonPoint.setMinter(address(dragonPointRewarder), true);

    address[] memory rewarders1 = new address[](4);
    rewarders1[0] = address(revenueRewarder);
    rewarders1[1] = address(esP88Rewarder);
    rewarders1[2] = address(dragonPointRewarder);
    rewarders1[3] = address(partnerARewarder);

    address[] memory rewarders2 = new address[](2);
    rewarders2[0] = address(revenueRewarder);
    rewarders2[1] = address(partnerARewarder);

    dragonStaking.addStakingToken(address(p88), rewarders1);
    dragonStaking.addStakingToken(address(esP88), rewarders1);
    dragonStaking.addStakingToken(address(dragonPoint), rewarders2);
    vm.stopPrank();
  }
}
