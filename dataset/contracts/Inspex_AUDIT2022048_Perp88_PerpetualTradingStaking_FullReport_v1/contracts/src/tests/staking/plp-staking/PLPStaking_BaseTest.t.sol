// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, PLPStaking, PLP, EsP88, MockErc20, MockWNative, FeedableRewarder, WFeedableRewarder } from "../../base/BaseTest.sol";

contract PLPStaking_BaseTest is BaseTest {
  PLP internal plp;
  EsP88 internal esP88;
  MockWNative internal revenueToken;
  MockErc20 internal partnerAToken;
  MockErc20 internal partnerBToken;

  PLPStaking internal plpStaking;

  WFeedableRewarder internal revenueRewarder;
  FeedableRewarder internal esP88Rewarder;
  FeedableRewarder internal partnerARewarder;
  FeedableRewarder internal partnerBRewarder;

  function setUp() public virtual {
    vm.startPrank(DAVE);
    plpStaking = BaseTest.deployPLPStaking();

    plp = BaseTest.deployPLP();
    plp.setMinter(DAVE, true);

    esP88 = BaseTest.deployEsP88();
    esP88.setMinter(DAVE, true);

    revenueToken = deployMockWNative();
    partnerAToken = BaseTest.deployMockErc20("Partner A", "PA", 18);
    partnerBToken = BaseTest.deployMockErc20("Partner B", "PB", 18);

    revenueRewarder = BaseTest.deployWFeedableRewarder(
      "Protocol Revenue Rewarder",
      address(revenueToken),
      address(plpStaking)
    );
    esP88Rewarder = BaseTest.deployFeedableRewarder(
      "esP88 Rewarder",
      address(esP88),
      address(plpStaking)
    );
    partnerARewarder = BaseTest.deployFeedableRewarder(
      "Partner A Rewarder",
      address(partnerAToken),
      address(plpStaking)
    );
    partnerBRewarder = BaseTest.deployFeedableRewarder(
      "Partner B Rewarder",
      address(partnerBToken),
      address(plpStaking)
    );

    address[] memory rewarders = new address[](3);
    rewarders[0] = address(revenueRewarder);
    rewarders[1] = address(esP88Rewarder);
    rewarders[2] = address(partnerARewarder);

    plpStaking.addStakingToken(address(plp), rewarders);

    plp.setWhitelist(address(plpStaking), true);
    vm.stopPrank();
  }
}
