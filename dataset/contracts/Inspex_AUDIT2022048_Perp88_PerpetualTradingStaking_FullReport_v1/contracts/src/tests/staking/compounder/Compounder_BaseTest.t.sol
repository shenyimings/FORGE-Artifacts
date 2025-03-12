// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import { BaseTest, PLPStaking, DragonStaking, PLP, P88, EsP88, DragonPoint, MockErc20, MockWNative, FeedableRewarder, WFeedableRewarder, AdHocMintRewarder, Compounder } from "../../base/BaseTest.sol";

contract Compounder_BaseTest is BaseTest {
  PLP internal plp;
  P88 internal p88;
  EsP88 internal esP88;
  DragonPoint internal dragonPoint;
  MockErc20 internal revenueToken;
  MockErc20 internal partnerAToken;
  MockErc20 internal partnerBToken;

  PLPStaking internal plpStaking;
  DragonStaking internal dragonStaking;

  FeedableRewarder internal revenuePLPPoolRewarder;
  FeedableRewarder internal esP88PLPPoolRewarder;

  FeedableRewarder internal esP88DragonPoolRewarder;
  FeedableRewarder internal revenueDragonPoolRewarder;
  FeedableRewarder internal partnerADragonPoolRewarder;
  AdHocMintRewarder internal dragonPointRewarder;

  Compounder internal compounder;

  function setUp() public virtual {
    vm.startPrank(DAVE);

    plp = BaseTest.deployPLP();
    plp.setMinter(DAVE, true);

    p88 = BaseTest.deployP88();
    p88.setMinter(DAVE, true);

    esP88 = BaseTest.deployEsP88();
    esP88.setMinter(DAVE, true);

    dragonPoint = BaseTest.deployDragonPoint();
    dragonPoint.setMinter(DAVE, true);

    partnerAToken = BaseTest.deployMockErc20("Partner A", "PA", 18);

    revenueToken = usdc;

    plpStaking = BaseTest.deployPLPStaking();

    revenuePLPPoolRewarder = BaseTest.deployFeedableRewarder(
      "Protocol Revenue PLP Pool Rewarder",
      address(revenueToken),
      address(plpStaking)
    );
    esP88PLPPoolRewarder = BaseTest.deployFeedableRewarder(
      "esP88 PLP Pool Rewarder",
      address(esP88),
      address(plpStaking)
    );

    dragonStaking = BaseTest.deployDragonStaking(address(dragonPoint));
    dragonPoint.setMinter(address(dragonStaking), true);
    dragonPoint.setTransferrer(address(dragonStaking), true);

    revenueDragonPoolRewarder = BaseTest.deployFeedableRewarder(
      "Protocol Revenue Dragon Pool Rewarder",
      address(revenueToken),
      address(dragonStaking)
    );
    esP88DragonPoolRewarder = BaseTest.deployFeedableRewarder(
      "esP88 Dragon Pool Rewarder",
      address(esP88),
      address(dragonStaking)
    );
    dragonPointRewarder = BaseTest.deployAdHocMintRewarder(
      "dp Dragon Pool Rewarder",
      address(dragonPoint),
      address(dragonStaking)
    );
    partnerADragonPoolRewarder = BaseTest.deployFeedableRewarder(
      "Partner A Dragon Pool Rewarder",
      address(partnerAToken),
      address(dragonStaking)
    );

    dragonStaking.setDragonPointRewarder(address(dragonPointRewarder));
    dragonPoint.setMinter(address(dragonPointRewarder), true);

    address[] memory rewarders = new address[](2);
    rewarders[0] = address(revenuePLPPoolRewarder);
    rewarders[1] = address(esP88PLPPoolRewarder);

    plpStaking.addStakingToken(address(plp), rewarders);

    address[] memory rewarders1 = new address[](4);
    rewarders1[0] = address(revenueDragonPoolRewarder);
    rewarders1[1] = address(esP88DragonPoolRewarder);
    rewarders1[2] = address(dragonPointRewarder);
    rewarders1[3] = address(partnerADragonPoolRewarder);

    address[] memory rewarders2 = new address[](2);
    rewarders2[0] = address(revenueDragonPoolRewarder);
    rewarders2[1] = address(partnerADragonPoolRewarder);

    dragonStaking.addStakingToken(address(p88), rewarders1);
    dragonStaking.addStakingToken(address(esP88), rewarders1);
    dragonStaking.addStakingToken(address(dragonPoint), rewarders2);

    address[] memory tokens = new address[](4);
    tokens[0] = address(esP88);
    tokens[1] = address(dragonPoint);
    tokens[2] = address(partnerAToken);
    tokens[3] = address(revenueToken);
    bool[] memory isCompoundTokens = new bool[](4);
    isCompoundTokens[0] = true;
    isCompoundTokens[1] = true;
    isCompoundTokens[2] = false;
    isCompoundTokens[3] = false;
    compounder = deployCompounder(
      address(dragonPoint),
      address(dragonStaking),
      tokens,
      isCompoundTokens
    );

    plpStaking.setCompounder(address(compounder));
    dragonStaking.setCompounder(address(compounder));
    dragonPoint.setTransferrer(address(compounder), true);

    plp.setWhitelist(address(plpStaking), true);

    vm.stopPrank();
  }
}
