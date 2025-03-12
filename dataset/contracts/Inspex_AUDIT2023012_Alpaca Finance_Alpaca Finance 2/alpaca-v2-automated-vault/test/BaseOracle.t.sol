// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

// dependencies
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";

// contracts
import { BaseOracle } from "src/oracles/BaseOracle.sol";

// fixtures
import "test/fixtures/BscFixture.f.sol";
import "test/fixtures/ProtocolActorFixture.f.sol";

// helpers
import { DeployHelper } from "test/helpers/DeployHelper.sol";

contract BaseOracleHarness is BaseOracle {
  function initialize() external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
  }

  function harness_safeGetTokenPriceE18(address _token) external view returns (uint256) {
    return _safeGetTokenPriceE18(_token);
  }
}

contract BaseOracleTest is BscFixture, ProtocolActorFixture {
  BaseOracleHarness oracle;

  constructor() BscFixture() ProtocolActorFixture() {
    vm.createSelectFork("bsc_mainnet", BscFixture.FORK_BLOCK_NUMBER_1);

    vm.startPrank(DEPLOYER);
    oracle = BaseOracleHarness(
      DeployHelper.deployUpgradeableFullPath(
        "./out/BaseOracle.t.sol/BaseOracleHarness.json", abi.encodeWithSelector(BaseOracleHarness.initialize.selector)
      )
    );
    vm.stopPrank();
  }

  function testCorrectness_SetPriceFeedOf() public {
    vm.prank(DEPLOYER);
    oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));

    assertEq(address(oracle.priceFeedOf(address(wbnb))), address(wbnbFeed));
  }

  function testRevert_SetPriceFeedOf_InvalidPriceFeed() public {
    vm.prank(DEPLOYER);
    vm.expectRevert();
    oracle.setPriceFeedOf(address(wbnb), address(0));
  }

  function testRevert_SetPriceFeedOf_NonOwner() public {
    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
  }

  function testCorrectness_SetMaxPriceAge() public {
    vm.prank(DEPLOYER);
    oracle.setMaxPriceAge(100);

    assertEq(oracle.maxPriceAge(), 100);
  }

  function testRevert_SetMaxPriceAge_NonOwner() public {
    vm.prank(USER_ALICE);
    vm.expectRevert("Ownable: caller is not the owner");
    oracle.setMaxPriceAge(100);
  }

  function testCorrectness_Harness_SafeGetTokenPriceE18() public {
    vm.startPrank(DEPLOYER);
    oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    oracle.setMaxPriceAge(100);
    vm.stopPrank();

    (, int256 answer,,,) = wbnbFeed.latestRoundData();
    // Convert answer to E18
    uint256 expectedPrice = uint256(answer) * (10 ** (18 - wbnbFeed.decimals()));
    assertEq(oracle.harness_safeGetTokenPriceE18(address(wbnb)), expectedPrice);
  }

  function testRevert_Harness_SafeGetTokenPriceE18_PriceTooOld() public {
    vm.startPrank(DEPLOYER);
    oracle.setPriceFeedOf(address(wbnb), address(wbnbFeed));
    oracle.setMaxPriceAge(100);
    vm.stopPrank();

    // Price from oracle is too old
    uint256 updatedAt = 0;
    vm.mockCall(
      address(wbnbFeed),
      abi.encodeWithSelector(IChainlinkAggregator.latestRoundData.selector),
      abi.encode(0, 0, 0, updatedAt, 0)
    );

    vm.expectRevert(BaseOracle.BaseOracle_PriceTooOld.selector);
    oracle.harness_safeGetTokenPriceE18(address(wbnb));
  }
}
