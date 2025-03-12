// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../pools/PoolUtils.sol";
import "../Emissions.sol";


contract TestEmissions is Deployment
	{
	address public alice = address(0x1111);
	address public bob = address(0x2222);

	bytes32 public pool1;
	bytes32 public pool2;


    function setUp() public
    	{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );
			}

		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

    	vm.startPrank( DEPLOYER );
    	IERC20 token1 = new TestERC20("TEST", 18);
		IERC20 token2 = new TestERC20("TEST", 18);
		IERC20 token3 = new TestERC20("TEST", 18);

        (pool1,) = PoolUtils._poolID(token1, token2);
        (pool2,) = PoolUtils._poolID(token2, token3);
		vm.stopPrank();

		// Whitelist pools
    	vm.startPrank( address(dao) );
		poolsConfig.whitelistPool(pools, token1, token2);
		poolsConfig.whitelistPool(pools, token2, token3);
		vm.stopPrank();

    	// Start with some SALT in the Emissions contract
    	vm.startPrank( DEPLOYER );
		salt.transfer(address(emissions), 1000 ether);

		// Send some SALT to alice and bob
		salt.transfer(alice, 100 ether);
		salt.transfer(bob, 100 ether);
		vm.stopPrank();

		vm.prank(alice);
		salt.approve( address(staking), type(uint256).max );

		vm.prank(bob);
		salt.approve( address(staking), type(uint256).max );
    	}


	function testPerformUpkeepOnlyCallableFromUpkeep() public
		{
		vm.expectRevert( "Emissions.performUpkeep is only callable from the Upkeep contract" );
        emissions.performUpkeep(2 weeks);

		vm.prank(address(upkeep));
        emissions.performUpkeep(2 weeks);
		}


	// A unit test to check the _performUpkeep function when the timeSinceLastUpkeep is zero. Verify that the function does not perform any actions.
	function testPerformUpkeepWithZeroTimeSinceLastUpkeep() public {

        // Call performUpkeep function
        uint256 initialSaltBalance = salt.balanceOf(address(emissions));

        vm.prank(address(upkeep));
        emissions.performUpkeep(0);

        // Since the calculated saltToSend was zero, no actions should be taken
        // Therefore, the SALT balance should be the same
        uint256 finalSaltBalance = salt.balanceOf(address(emissions));
        assertEq(initialSaltBalance, finalSaltBalance);
    }



	// A unit test to check the constructor when the _exchangeConfig parameter is a zero address.
	function testEmissionsConstructorWithZeroAddressExchangeConfig() public {
    	vm.expectRevert("_exchangeConfig cannot be address(0)");
    	new Emissions(saltRewards, IExchangeConfig(address(0)), rewardsConfig);
    }


    // A unit test to check the constructor when the _rewardsConfig parameter is a zero address.
    function testEmissionsConstructorWithZeroAddressRewardsConfig() public {
        	vm.expectRevert("_rewardsConfig cannot be address(0)");
        	new Emissions(saltRewards, exchangeConfig, IRewardsConfig(address(0)));
        }


    // A unit test to check the performUpkeep function when the remaining SALT balance is zero.
    function testPerformUpkeepWithZeroSaltBalance() public
        {
        // Transfer all remaining SALT
        vm.startPrank(address(emissions));
        salt.transfer(address(alice), salt.balanceOf(address(emissions)));
        vm.stopPrank();

        // Ensure all SALT is transferred
        assertEq(salt.balanceOf(address(emissions)), 0);

        // Call performUpkeep function
        vm.prank(address(upkeep));
        emissions.performUpkeep(2 weeks);

        // Since SALT balance was zero, no actions should be taken
        // Therefore, the initial and final SALT balances should be the same
        assertEq(salt.balanceOf(address(emissions)), 0);
        }


    // A unit test to validate that the contract initialization fails when the _saltRewards is a zero address.
	function testEmissionsConstructorWithZeroAddressSaltRewards() public {
        vm.expectRevert("_saltRewards cannot be address(0)");
        new Emissions(ISaltRewards(address(0)), exchangeConfig, rewardsConfig);
    }


    // A unit test to verify SALT approval to saltRewards in the performUpkeep function.
    function testPerformUpkeepApprovesSALTRewards() public {

		uint256 startingEmissionsBalance = salt.balanceOf(address(emissions));

    	// Perform upkeep as if 1 week has passed
    	vm.prank(address(upkeep));
    	emissions.performUpkeep(1 weeks);

		// Expected sent rewards to saltRewads should be .5% of 1000 ether (both set in the constructor)
		uint256 expectedRewards = 1000 ether * 5 / 1000;
		assertEq( salt.balanceOf(address(saltRewards)), expectedRewards);

    	// All of the allowance should have been sent
    	uint256 allowance = salt.allowance(address(emissions), address(saltRewards));

		assertEq( allowance, 0);
		assertEq( salt.balanceOf(address(emissions)), startingEmissionsBalance - expectedRewards);
    }


	// A unit test to test that increasing emissionsWeeklyPercentTimes1000 to 1% has the desired effect
	function testEmissionsWeeklyPercentTimes1000() public
		{
		uint256 startingEmissionsBalance = salt.balanceOf(address(emissions));

		// Increase emissionsWeeklyPercent to 1% weekly for testing (.50% default + 2x 0.25% increment)
    	vm.startPrank( address(dao) );
		rewardsConfig.changeEmissionsWeeklyPercent(true);
        rewardsConfig.changeEmissionsWeeklyPercent(true);
        vm.stopPrank();

    	// Perform upkeep as if 1 week has passed
    	vm.prank(address(upkeep));
    	emissions.performUpkeep(1 weeks);

		// Expected sent rewards to saltRewads should be 1% of 1000 ether (both set in the constructor)
		uint256 expectedRewards = 1000 ether * 1 / 100;
		assertEq( salt.balanceOf(address(saltRewards)), expectedRewards);

		assertEq( salt.balanceOf(address(emissions)), startingEmissionsBalance - expectedRewards);
		}


    uint256 constant public MAX_TIME_SINCE_LAST_UPKEEP = 1 weeks;

	// A unit test to check the amount of SALT rewards sent in performUpkeep when timeSinceLastUpkeep is greater than MAX_TIME_SINCE_LAST_UPKEEP.
	function testPerformUpkeepMaxTimeSinceLastUpkeep() public
		{
		uint256 initialSaltBalance = salt.balanceOf(address(emissions));

		// Perform upkeep with a time greater than MAX_TIME_SINCE_LAST_UPKEEP
		vm.prank(address(upkeep));
		emissions.performUpkeep(MAX_TIME_SINCE_LAST_UPKEEP + 1);

		// Despite providing a time greater than MAX_TIME_SINCE_LAST_UPKEEP, only MAX_TIME_SINCE_LAST_UPKEEP should be considered
		// Weekly emission rate is .50%, so the expected salt sent is .50% of the initial balance
		uint256 expectedSaltSent = initialSaltBalance * 5 / 1000;
		uint256 finalSaltBalance = salt.balanceOf(address(emissions));
		assertEq(initialSaltBalance - finalSaltBalance, expectedSaltSent);
		}

	}
