// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../ExchangeConfig.sol";
import "../../pools/Pools.sol";
import "../../staking/Liquidity.sol";
import "../../staking/Staking.sol";
import "../../stable/Collateral.sol";
import "../../rewards/RewardsEmitter.sol";
import "../../price_feed/tests/IForcedPriceFeed.sol";
import "../../pools/PoolsConfig.sol";
import "../../price_feed/PriceAggregator.sol";
import "../../AccessManager.sol";
import "../InitialDistribution.sol";
import "../../Upkeep.sol";
import "../../dao/Proposals.sol";
import "../../dao/DAO.sol";


contract TestInitialDistribution is Deployment
	{
	uint256 constant public MILLION_ETHER = 1000000 ether;


	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			// Transfer the salt from the original initialDistribution to the DEPLOYER
			vm.prank(address(initialDistribution));
			salt.transfer(DEPLOYER, 100 * MILLION_ETHER);

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

			airdrop = new Airdrop(exchangeConfig, staking);

			accessManager = new AccessManager(dao);

			exchangeConfig.setAccessManager( accessManager );
			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
			exchangeConfig.setDAO( dao );
			exchangeConfig.setAirdrop(airdrop);

			saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);

			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
			exchangeConfig.setUpkeep(upkeep);

			initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);
			exchangeConfig.setInitialDistribution(initialDistribution);

			pools.setDAO(dao);

			usds.setContracts(collateral, pools, exchangeConfig );

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

			// Transfer SALT to the new InitialDistribution contract
			vm.startPrank(DEPLOYER);
			salt.transfer(address(initialDistribution), 100 * MILLION_ETHER);
			vm.stopPrank();
			}

		whitelistAlice();
		}


	// A unit test to ensure the constructor has correctly set the input parameters.
	function testInitial_distribution_constructor() public
    {
    	InitialDistribution initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);

    	assertEq(address(initialDistribution.salt()), address(salt), "error in initialDistribution.salt()");
    	assertEq(address(initialDistribution.poolsConfig()), address(poolsConfig), "error in initialDistribution.poolsConfig()");
    	assertEq(address(initialDistribution.emissions()), address(emissions), "error in initialDistribution.emissions()");
    	assertEq(address(initialDistribution.bootstrapBallot()), address(bootstrapBallot), "error in initialDistribution.bootstrapBallot()");
    	assertEq(address(initialDistribution.dao()), address(dao), "error in initialDistribution.dao()");
    	assertEq(address(initialDistribution.daoVestingWallet()), address(daoVestingWallet), "error in initialDistribution.daoVestingWallet()");
    	assertEq(address(initialDistribution.teamVestingWallet()), address(teamVestingWallet), "error in initialDistribution.teamVestingWallet()");
    	assertEq(address(initialDistribution.airdrop()), address(airdrop), "error in initialDistribution.airdrop()");
    	assertEq(address(initialDistribution.saltRewards()), address(saltRewards), "error in initialDistribution.saltRewards()");
    	assertEq(address(initialDistribution.liquidity()), address(liquidity), "error in initialDistribution.liquidity()");
    }


	// A unit test to verify that the `distributionApproved` function can only be called from the BootstrapBallot contract.
	function testCannotCallDistributionApprovedFromInvalidAddress() public {
        InitialDistribution id = new InitialDistribution( salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity );

        vm.expectRevert("InitialDistribution.distributionApproved can only be called from the BootstrapBallot contract");
        id.distributionApproved();
    }


	// A unit test to ensure SALT has not already been sent from the contract when `distributionApproved` is called. If SALT has already been sent, calling `distributionApproved` should fail.
	function testDistributionApprovedWithAlreadySentSalt() public {

		// Transfer SALT from the InitialDistribution contract
		uint256 saltBalance = salt.balanceOf(address(initialDistribution));

		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, saltBalance);

    	// Attempting to call distributionApproved should revert due to SALT already being sent
    	vm.prank(address(bootstrapBallot));

    	vm.expectRevert("SALT has already been sent from the contract");
    	initialDistribution.distributionApproved();
    }


	// A unit test to check that correct amounts of SALT have been distributed and initial liquidity formed on a call to distributionApproved()
	function testSaltTransferOnDistributionApproved() public {

		assertEq(salt.balanceOf(address(emissions)), 0);
		assertEq(salt.balanceOf(address(daoVestingWallet)), 0);
		assertEq(salt.balanceOf(address(teamVestingWallet)), 0);
		assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), 0);
		assertEq(salt.balanceOf(address(stakingRewardsEmitter)), 0);

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

    	// Emissions							52 million
	    // DAO Reserve Vesting Wallet	25 million
	    // Initial Team Vesting Wallet	10 million
	    // Airdrop Participants				5 million
	    // Liquidity Bootstrapping		5 million
	    // Staking Bootstrapping			3 million

		assertEq(salt.balanceOf(address(emissions)), 52 * MILLION_ETHER);
		assertEq(salt.balanceOf(address(daoVestingWallet)), 25 * MILLION_ETHER);
		assertEq(salt.balanceOf(address(teamVestingWallet)), 10 * MILLION_ETHER);
		assertEq(salt.balanceOf(address(airdrop)), 5 * MILLION_ETHER);
		assertEq(salt.balanceOf(address(liquidityRewardsEmitter)), 4999999999999999999999995);
		assertEq(salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005);

		assertEq( salt.balanceOf(address(initialDistribution)), 0 );
	}


	// A unit test to ensure that the contract initialization fails if a 0 address is provided for any of the parameters in the constructor.
function testConstructorInitializationWithZeroAddress() public {
    address zeroAddress = address(0);
    InitialDistribution initialDist;

    vm.expectRevert( "_salt cannot be address(0)" );
    initialDist = new InitialDistribution(ISalt(zeroAddress), poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);

    vm.expectRevert( "_poolsConfig cannot be address(0)" );
    initialDist = new InitialDistribution(salt, IPoolsConfig(zeroAddress), emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);

    vm.expectRevert( "_emissions cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, IEmissions(zeroAddress), bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);

    vm.expectRevert( "_dao cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, IDAO(zeroAddress), daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);

    vm.expectRevert( "_daoVestingWallet cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot,dao, VestingWallet(payable(zeroAddress)), teamVestingWallet, airdrop, saltRewards, liquidity);

    vm.expectRevert( "_teamVestingWallet cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, VestingWallet(payable(zeroAddress)), airdrop, saltRewards, liquidity);

    vm.expectRevert( "_airdrop cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, IAirdrop(zeroAddress), saltRewards, liquidity);

    vm.expectRevert( "_saltRewards cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, ISaltRewards(zeroAddress), liquidity);

    vm.expectRevert( "_liquidity cannot be address(0)" );
    initialDist = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, ILiquidity(zeroAddress));
}

	// A unit test to ensure the `distributionApproved` function can only be called once and subsequent calls fail.
	function testDistributionApproved_callTwice() public {
		vm.prank(DEPLOYER);
		weth.transfer(address(dao), 1000 ether);

        // First call should succeed
        vm.prank(address(bootstrapBallot));
        initialDistribution.distributionApproved();

        // Verify the balance of SALT contract is zero after distribution
        assertEq(salt.balanceOf(address(initialDistribution)), 0);

        // Second call should revert
        vm.expectRevert("SALT has already been sent from the contract");
        vm.prank(address(bootstrapBallot));
        initialDistribution.distributionApproved();
    }


	// A unit test to check that the Airdrop contract has been setup correctly on a call to distributionApproved()
	function testAirdropSetupOnDistributionApproved() public {

		// Create some dummy aidrop recipients
		whitelistAlice();
		whitelistBob();
		whitelistCharlie();

		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Make sure claiming has been activated for airdrop
		assertTrue( airdrop.claimingAllowed() );
		assertEq( airdrop.numberAuthorized(), 3 );
		assertEq( salt.balanceOf(address(airdrop)), 5 * MILLION_ETHER );

		assertEq( airdrop.saltAmountForEachUser(), 5 * MILLION_ETHER / 3 );
	}
    }

