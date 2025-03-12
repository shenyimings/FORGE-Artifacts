// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "../../pools/PoolUtils.sol";
import "../ArbitrageSearch.sol";
import "../../pools/Counterswap.sol";
import "../../rewards/SaltRewards.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../stable/Collateral.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Staking.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../price_feed/tests/IForcedPriceFeed.sol";
import "../../price_feed/tests/ForcedPriceFeed.sol";
import "../../pools/PoolsConfig.sol";
import "../../price_feed/PriceAggregator.sol";
import "../../dao/Proposals.sol";
import "../../dao/DAO.sol";
import "../../AccessManager.sol";
import "./TestArbitrageSearch.sol";


contract TestArbitrageSearch2 is Deployment
	{
	address public alice = address(0x1111);

	TestArbitrageSearch public testArbitrageSearch = new TestArbitrageSearch( exchangeConfig);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();
			usds = new USDS(wbtc, weth);

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

			pools = new Pools(exchangeConfig, poolsConfig);
			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool(pools, salt, wbtc);
			poolsConfig.whitelistPool(pools, salt, weth);
			poolsConfig.whitelistPool(pools, salt, usds);
			poolsConfig.whitelistPool(pools, wbtc, usds);
			poolsConfig.whitelistPool(pools, weth, usds);
			poolsConfig.whitelistPool(pools, wbtc, dai);
			poolsConfig.whitelistPool(pools, weth, dai);
			poolsConfig.whitelistPool(pools, usds, dai);
			poolsConfig.whitelistPool(pools, wbtc, weth);


			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

			accessManager = new AccessManager(dao);

			exchangeConfig.setAccessManager( accessManager );
			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
			exchangeConfig.setDAO( dao );

			testArbitrageSearch = new TestArbitrageSearch( exchangeConfig);

			pools.setDAO(dao);

			usds.setContracts( collateral, pools, exchangeConfig );

			// Transfer ownership of the newly created config files to the DAO
			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
			Ownable(address(priceAggregator)).transferOwnership(address(dao));
			vm.stopPrank();

			vm.startPrank(address(oldDAO));
			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
			Ownable(address(stableConfig)).transferOwnership( address(dao) );
			Ownable(address(daoConfig)).transferOwnership( address(dao) );
			vm.stopPrank();
			}

		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);
		}


	// A unit test that validates that binarySearch returns zero when pool reserves are at or below the threshold of PoolUtils.DUST.
	function testBinarySearchReturnsZeroWhenReservesBelowDUST() public {
        uint256 swapAmountInValueInETH = 1 ether; // Just an arbitrary value

        // Case where all reserves are below or at DUST
        uint256 reservesA0 = PoolUtils.DUST;
        uint256 reservesA1 = PoolUtils.DUST;
        uint256 reservesB0 = PoolUtils.DUST;
        uint256 reservesB1 = PoolUtils.DUST;
        uint256 reservesC0 = PoolUtils.DUST;
        uint256 reservesC1 = PoolUtils.DUST;
        uint256 reservesD0 = PoolUtils.DUST;
        uint256 reservesD1 = PoolUtils.DUST;

        uint256 bestArbAmountIn = testArbitrageSearch.binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1);
        assertEq(bestArbAmountIn, 0);

        // Case where some reserves are above DUST
        reservesA0 = PoolUtils.DUST + 1;
        reservesA1 = PoolUtils.DUST + 1;
        reservesB0 = PoolUtils.DUST + 1;
        reservesC1 = PoolUtils.DUST + 1;

        bestArbAmountIn = testArbitrageSearch.binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1);
        assertEq(bestArbAmountIn, 0);
    }


	// A unit test that checks the constructor rejects an initialization with a zero address for _exchangeConfig.
	function testConstructorShouldFailWhenExchangeConfigIsZeroAddress() public {
        // Expect a revert due to a zero address being passed to the constructor
        vm.expectRevert("_exchangeConfig cannot be address(0)");
        new TestArbitrageSearch(IExchangeConfig(address(0)));
    }


	// A unit test that simulates failed or reverted transactions within the arbitrage paths.
	function testFailArbitragePaths() public {
        uint256 swapAmountInValueInETH = 5 ether;  // Arbitrary value for test
        uint256 reservesA0 = 1000 ether; // Also arbitrary
        uint256 reservesA1 = 2000 ether;
        uint256 reservesB0 = 1500 ether;
        uint256 reservesB1 = 3000 ether;
        uint256 reservesC0 = 2500 ether;
        uint256 reservesC1 = 5000 ether;
        uint256 reservesD0 = 0;  // For simulating the reverted cases
        uint256 reservesD1 = 0;

        vm.expectRevert("reservesD0 or reservesD1 should be more than DUST");
        testArbitrageSearch.binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1);

        // Simulating other reverts
        reservesD0 = 100 ether;
        reservesD1 = 0;
        vm.expectRevert("reservesD0 or reservesD1 should be more than DUST");
        testArbitrageSearch.binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1);

        reservesA0 = 0;
        vm.expectRevert("reservesA0 or reservesA1 should be more than DUST");
        testArbitrageSearch.binarySearch(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1);
    }
	}


