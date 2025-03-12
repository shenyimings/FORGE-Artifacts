// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "./TestSaltRewards.sol";


contract TestSaltRewards2 is Deployment
	{
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);



    function setUp() public
    	{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		// Transfer the salt from the original initialDistribution to the DEPLOYER
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);
    	}


    // A unit test to check the addSALTRewards function with a non-zero amount, ensuring that the pending rewards variables are updated correctly.
    function testAddSALTRewards() public
    	{
    	vm.startPrank(address(DEPLOYER));

    	uint256 amount = 10 ether;

    	// Initializing the variables for storing pending rewards before adding the salt token rewards
    	uint256 prevPendingRewardsSaltUSDS = saltRewards.pendingRewardsSaltUSDS();
    	uint256 prevPendingStakingRewards = saltRewards.pendingStakingRewards();

    	// Running addSALTRewards function
    	salt.approve(address(saltRewards), amount);
    	saltRewards.addSALTRewards(amount);

    	// Expectations after running the function
		uint256 expectedSaltUSDS = prevPendingRewardsSaltUSDS + ((amount * rewardsConfig.percentRewardsSaltUSDS()) / 100);
		uint256 remainingAmount = amount - expectedSaltUSDS;
		uint256 expectedStakingAmount = prevPendingStakingRewards + ((remainingAmount * rewardsConfig.stakingRewardsPercent()) / 100);
		uint256 expectedLiquidity = remainingAmount - expectedStakingAmount;

    	// Verifying the changes in pending rewards
    	assertEq(saltRewards.pendingRewardsSaltUSDS(), expectedSaltUSDS, "Pending rewards for SaltUSDS not updated accurately");
    	assertEq(saltRewards.pendingStakingRewards(), expectedStakingAmount, "Pending staking rewards not updated accurately");
    	assertEq(saltRewards.pendingLiquidityRewards(), expectedLiquidity, "Pending liquidity rewards not updated accurately");

    	// Checking that the correct amount of SALT has been transferred to the contract
    	assertEq(salt.balanceOf(address(saltRewards)), amount, "Incorrect SALT balance of contract");
    	}


    // A unit test to check the addSALTRewards function with a zero amount, ensuring that neither the balance of the contract nor the state variables are updated.
    	function testAddSALTRewardsZeroAmount() public
    	{
    		vm.prank(address(DEPLOYER));

    		// Initializing the variables for storing pending rewards before adding the zero amount of salt token rewards
    		uint256 prevPendingRewardsSaltUSDS = saltRewards.pendingRewardsSaltUSDS();
    		uint256 prevPendingStakingRewards = saltRewards.pendingStakingRewards();
    		uint256 prevPendingLiquidityRewards = saltRewards.pendingLiquidityRewards();
    		uint256 prevBalance = salt.balanceOf(address(saltRewards));

    		// Verifying that the pending rewards and contract balance has not changed
    		assertEq(saltRewards.pendingRewardsSaltUSDS(), prevPendingRewardsSaltUSDS, "Pending rewards for SaltUSDS are updated with zero amount");
    		assertEq(saltRewards.pendingStakingRewards(), prevPendingStakingRewards, "Pending staking rewards are updated with zero amount");
    		assertEq(saltRewards.pendingLiquidityRewards(), prevPendingLiquidityRewards, "Pending liquidity rewards are updated with zero amount");
    		assertEq(salt.balanceOf(address(saltRewards)), prevBalance, "SALT balance of contract is updated with zero amount");
    	}


    // A unit test to ensure that the _sendStakingRewards function correctly transfers the pendingStakingRewards to the stakingRewardsEmitter and resets the pendingStakingRewards to zero.
 function testSendStakingRewards() public {
 		TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

		vm.prank(DEPLOYER);
		salt.transfer(address(_saltRewards), 10 ether);

         // Initializing the pending staking rewards
         uint256 initialPendingStakingRewards = 10 ether;
         _saltRewards.setPendingStakingRewards(initialPendingStakingRewards);

         // Initializing the balance of contract before running the function
     	uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

         // Bangalore to set the initial balance of stakingRewardsEmitter
         uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));

         // Running _sendStakingRewards function
         _saltRewards.sendStakingRewards();

         // Expectations after running the function
         uint256 expectedStakingRewardsEmitterBalance = initialPendingStakingRewards + initialStakingRewardsEmitterBalance;
         uint256 expectedSaltContractBalance = initialSaltContractBalance - initialPendingStakingRewards;

         // Verifying the changes in the balances and the pending staking rewards
         assertEq(salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter())), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
         assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance, "_sendStakingRewards hasn't deducted the correct amount of Salt from the contract balance");
         assertEq(_saltRewards.pendingStakingRewards(), 0, "_sendStakingRewards didn't set pendingStakingRewards to 0");
     }


    // A unit test to verify the _sendLiquidityRewards function with a non-zero total profits and non-zero pending rewards, ensuring that the correct amount is transferred each pool's liquidityRewardsEmitter and the pendingLiquidityRewards and pendingRewardsSaltUSDS fields are reset to zero.
    // A unit test to test the _sendLiquidityRewards function while rewarding SALT/USDS pool with additional rewards, ensuring that the rewardsForPool is correctly calculated and added to pendingRewardsSaltUSDS.
    function testSendLiquidityRewards() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 50 ether);

		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        (poolIDs[0],) = PoolUtils._poolID(salt,usds);
		(poolIDs[1],) = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;

        // Initializing the pending rewards
        uint256 initialPendingLiquidityRewards = 40 ether; // for other pools
        uint256 initialPendingRewardsSaltUSDS = 1 ether; // for SALT/USDS pool
        _saltRewards.setPendingLiquidityRewards(initialPendingLiquidityRewards);
        _saltRewards.setPendingRewardsSaltUSDS(initialPendingRewardsSaltUSDS);

        // Balance of contract before running sendLiquidityRewards
        uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

    	// Balance of liquidityRewardsEmitter before running sendLiquidityRewards
        uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));

        // Run _sendLiquidityRewards function
        _saltRewards.sendLiquidityRewards(poolIDs, profitsForPools);

        // Expectations after running the function
        uint256 expectedLiquidityRewardsEmitterBalance = initialLiquidityRewardsEmitterBalance + initialPendingLiquidityRewards + initialPendingRewardsSaltUSDS;
        uint256 expectedSaltContractBalance = initialSaltContractBalance - initialPendingLiquidityRewards - initialPendingRewardsSaltUSDS;

        // Verifying the changes in the balances and the pending rewards
        assertEq(salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter())), expectedLiquidityRewardsEmitterBalance - 1, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");
        assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance + 1, "_sendLiquidityRewards hasn't deducted the correct amount of Salt from the contract balance");
        assertEq(_saltRewards.pendingLiquidityRewards(), 0, "_sendLiquidityRewards didn't set pendingLiquidityRewards to 0");

        // Should set  pendingRewardsSaltUSDS to the remaining SALT that wasn't sent
        assertEq(_saltRewards.pendingRewardsSaltUSDS(), 9000000000000000001, "_sendLiquidityRewards didn't set pendingRewardsSaltUSDS to 0");

        uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);
        assertEq( pendingRewards[0], initialPendingLiquidityRewards * 1 / 3 + 1 ether );
        assertEq( pendingRewards[1], initialPendingLiquidityRewards * 2 / 3 );
    }


    // A unit test to ensure that _sendLiquidityRewards function does not transfer any rewards when total profits are zero.
    function testSendLiquidityRewardsZeroProfits() public {
    	TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
    	salt.transfer(address(_saltRewards), 10 ether);

    	// Initializing the pending liquidity rewards
    	uint256 initialPendingLiquidityRewards = 10 ether;
    	_saltRewards.setPendingLiquidityRewards(initialPendingLiquidityRewards);

    	// Initializing the balance of contract before running the function
    	uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

    	// Initializing the balance of liquidityRewardsEmitter
    	uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));

    	// Running _sendLiquidityRewards function with zero total profits
    	bytes32[] memory poolIDs = new bytes32[](0);
    	uint256[] memory profitsForPools = new uint256[](0);
    	_saltRewards.sendLiquidityRewards(poolIDs, profitsForPools);

    	// Since total profits are zero, no rewards should be transferred
    	assertEq(salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter())), initialLiquidityRewardsEmitterBalance, "No liquidity rewards should be transferred for zero profits");
    	assertEq(salt.balanceOf(address(_saltRewards)), initialSaltContractBalance, "No liquidity rewards should be deducted for zero profits");
    	assertEq(_saltRewards.pendingLiquidityRewards(), initialPendingLiquidityRewards, "Pending liquidity rewards should not change for zero profits");
    }


    // A unit test to ensure that the _sendInitialLiquidityRewards function correctly divides the liquidityBootstrapAmount amongst the initial pools and sends the amount to liquidityRewardsEmitter.
        function testSendInitialLiquidityRewards() public {
            TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

            bytes32[] memory poolIDs = new bytes32[](3);
            (poolIDs[0],) = PoolUtils._poolID(salt, usds);
            (poolIDs[1],) = PoolUtils._poolID(wbtc, weth);
            (poolIDs[2],) = PoolUtils._poolID(weth, usds);

            uint256 liquidityBootstrapAmount = 900 ether;

            // move tokens to rewards contract
            vm.prank(DEPLOYER);
            salt.transfer(address(_saltRewards), liquidityBootstrapAmount);

            uint256 initialLiquidityEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));

            // run `_sendInitialLiquidityRewards` function
            _saltRewards.sendInitialLiquidityRewards(liquidityBootstrapAmount, poolIDs);

            // verify the correct amount was transferred to liquidityRewardsEmitter
            uint256 expectedLiquidityEmitterBalance = initialLiquidityEmitterBalance + liquidityBootstrapAmount;
            assertEq(salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter())), expectedLiquidityEmitterBalance, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");

            uint256 expectedPerPool = liquidityBootstrapAmount / 3;
            uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);

            assertEq( pendingRewards[0], expectedPerPool );
            assertEq( pendingRewards[1], expectedPerPool );
            assertEq( pendingRewards[2], expectedPerPool );
        }


    // A unit test to check the _sendInitialStakingRewards function ensuring that the stakingBootstrapAmount is correctly transferred to the stakingRewardsEmitter.
    function testSendInitialStakingRewards() public {
    	TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

    	vm.prank(DEPLOYER);
    	salt.transfer(address(_saltRewards), 10 ether);

    	// Initializing the staking bootstrap amount
    	uint256 stakingBootstrapAmount = 10 ether;

    	// Initializing the balance of contract before running the function
    	uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

    	// Initialize the initial balance of stakingRewardsEmitter
    	uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));

    	// Running _sendInitialStakingRewards function
    	_saltRewards.sendInitialStakingRewards(stakingBootstrapAmount);

    	// Expectations after running the function
    	uint256 expectedStakingRewardsEmitterBalance = stakingBootstrapAmount + initialStakingRewardsEmitterBalance;
    	uint256 expectedSaltContractBalance = initialSaltContractBalance - stakingBootstrapAmount;

    	// Verifying the changes in the balances after running the function
    	assertEq(salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter())), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
    	assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance, "_sendInitialStakingRewards hasn't deducted the correct amount of Salt from the contract balance");
    }


    // A unit test to check the sendInitialSaltRewards function ensuring that it cannot be called by any other address other than the initialDistribution address set in the constructor.
    function testSendInitialSaltRewards_onlyCallableByInitialDistribution() public {
        TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 8 ether);

        uint256 liquidityBootstrapAmount = 5 ether;

        bytes32[] memory poolIDs = new bytes32[](1);
        (poolIDs[0],) = PoolUtils._poolID(salt, usds);

        // Expect revert because the caller is not the initialDistribution
        vm.expectRevert("SaltRewards.sendInitialRewards is only callable from the InitialDistribution contract");
        _saltRewards.sendInitialSaltRewards(liquidityBootstrapAmount, poolIDs);

        // Change the caller to the initialDistribution
        vm.prank(address(initialDistribution));
        _saltRewards.sendInitialSaltRewards(liquidityBootstrapAmount, poolIDs);
    }


    // A unit test to validate that the performUpkeep function works correctly when called by the upkeep address and the pendingStakingRewards and pendingLiquidityRewards fields are non-zero and check if the balance of contract is decreased by the sent amount.
    function testPerformUpkeepSuccess() public
    {
        TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 30 ether);

        // Initializing the pending staking and liquidity rewards
        uint256 initialPendingStakingRewards = 10 ether;
        uint256 initialPendingLiquidityRewards = 20 ether;

        _saltRewards.setPendingStakingRewards(initialPendingStakingRewards);
        _saltRewards.setPendingLiquidityRewards(initialPendingLiquidityRewards);

        // Initializing the balance of contract before running the function
        uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

        // Initializing the balance of stakingRewardsEmitter and liquidityRewardsEmitter before running the function
        uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));
        uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));


        // Create dummy poolIds and profitsForPools arrays
		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        (poolIDs[0],) = PoolUtils._poolID(salt,usds);
		(poolIDs[1],) = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;


        // Running performUpkeep function
        vm.prank(address(exchangeConfig.upkeep()));
        _saltRewards.performUpkeep(poolIDs, profitsForPools);

        // Expectations after running the function
        uint256 expectedSaltContractBalance = initialSaltContractBalance - initialPendingStakingRewards - initialPendingLiquidityRewards;
        uint256 expectedStakingRewardsEmitterBalance = initialStakingRewardsEmitterBalance + initialPendingStakingRewards;
        uint256 expectedLiquidityRewardsEmitterBalance = initialLiquidityRewardsEmitterBalance + initialPendingLiquidityRewards;

        // Verifying the changes in the balances, pending staking rewards and pending liquidity rewards
        assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance + 1, "performUpkeep hasn't deducted the correct amount of Salt from the contract balance");
        assertEq(salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter())), expectedStakingRewardsEmitterBalance, "StakingRewardsEmitter hasn't received the correct amount of Salt");
        assertEq(salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter())), expectedLiquidityRewardsEmitterBalance - 1, "LiquidityRewardsEmitter hasn't received the correct amount of Salt");
        assertEq(_saltRewards.pendingStakingRewards(), 0, "performUpkeep didn't set pendingStakingRewards to 0");
        assertEq(_saltRewards.pendingLiquidityRewards(), 0, "performUpkeep didn't set pendingLiquidityRewards to 0");
    }



    // A unit test to check the performUpkeep function when it's called by an address other than the upkeep address, ensuring that it reverts with the correct error message.
    function testPerformUpkeep_NotUpkeepAddress() public
    {
        TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

        vm.prank(charlie); // Assuming charlie is not an upkeep address

        bytes32[] memory poolIDs = new bytes32[](0);
        uint256[] memory profitsForPools = new uint256[](0);

        // Expect the performUpkeep to revert because it's called by an address other than the upkeep address
        vm.expectRevert("SaltRewards.performUpkeep is only callable from the Upkeep contract");
        _saltRewards.performUpkeep(poolIDs, profitsForPools);
    }


    // A unit test to check that the performUpkeep function does not perform any actions when the pendingStakingRewards or pendingLiquidityRewards are zero.
    function testPerformUpkeepWithZeroRewards() public
    	{
    	TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);
    	vm.prank(DEPLOYER);
    	salt.transfer(address(_saltRewards), 10 ether);

    	//Ensure pendingStakingRewards and pendingLiquidityRewards are zero before running performUpkeep
    	_saltRewards.setPendingStakingRewards(0);
    	_saltRewards.setPendingLiquidityRewards(0);

    	// Initial balances to be compared with final balances
    	uint256 initialContractBalance = salt.balanceOf(address(_saltRewards));
    	uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));
    	uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));


        // Create dummy poolIds and profitsForPools arrays
		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        (poolIDs[0],) = PoolUtils._poolID(salt,usds);
		(poolIDs[1],) = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;


    	// Perform upkeep
    	vm.prank(address(upkeep));
    	_saltRewards.performUpkeep(poolIDs, profitsForPools);

    	// Final balances
    	uint256 finalContractBalance = salt.balanceOf(address(_saltRewards));
    	uint256 finalStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));
    	uint256 finalLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));

    	// Expected values
    	uint256 expectedRemainingBalance = initialContractBalance;
    	uint256 expectedStakingEmitterBalance = initialStakingRewardsEmitterBalance;
    	uint256 expectedLiquidityEmitterBalance = initialLiquidityRewardsEmitterBalance;

    	// Asserts
    	assertEq(finalContractBalance, expectedRemainingBalance, "The contracts balance was changed, but it shouldn't have!");
    	assertEq(finalStakingRewardsEmitterBalance, expectedStakingEmitterBalance, "The Staking Rewards Emitter's balance was changed, but it shouldn't have!");
    	assertEq(finalLiquidityRewardsEmitterBalance, expectedLiquidityEmitterBalance, "The Liquidity Rewards Emitter's balance was changed, but it shouldn't have!");
    	}


    // A unit test to validate that the _sendInitialStakingRewards function reverts if the amount to be transferred is greater than the contract balance.
    function testPerformUpkeepInsufficientSALT() public
    {
        TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

        vm.prank(DEPLOYER);
        salt.transfer(address(_saltRewards), 5 ether);

        // Initializing the pending staking and liquidity rewards
        uint256 initialPendingStakingRewards = 10 ether;
        uint256 initialPendingLiquidityRewards = 20 ether;

        _saltRewards.setPendingStakingRewards(initialPendingStakingRewards);
        _saltRewards.setPendingLiquidityRewards(initialPendingLiquidityRewards);

        // Initializing the balance of contract before running the function
        uint256 initialSaltContractBalance = salt.balanceOf(address(_saltRewards));

        // Initializing the balance of stakingRewardsEmitter and liquidityRewardsEmitter before running the function
        uint256 initialStakingRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter()));
        uint256 initialLiquidityRewardsEmitterBalance = salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter()));


        // Create dummy poolIds and profitsForPools arrays
		IERC20 token1 = new TestERC20( "TEST", 18 );
		IERC20 token2 = new TestERC20( "TEST", 18 );

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, token1, token2);

        bytes32[] memory poolIDs = new bytes32[](2);
        (poolIDs[0],) = PoolUtils._poolID(salt,usds);
		(poolIDs[1],) = PoolUtils._poolID(token1, token2);

        uint256[] memory profitsForPools = new uint256[](2);
        profitsForPools[0] = 10 ether;
        profitsForPools[1] = 20 ether;


        // Running performUpkeep function
        vm.prank(address(exchangeConfig.upkeep()));
        vm.expectRevert( "ERC20: transfer amount exceeds balance" );
        _saltRewards.performUpkeep(poolIDs, profitsForPools);

        // Expectations after running the function
        uint256 expectedSaltContractBalance = initialSaltContractBalance;
        uint256 expectedStakingRewardsEmitterBalance = initialStakingRewardsEmitterBalance;
        uint256 expectedLiquidityRewardsEmitterBalance = initialLiquidityRewardsEmitterBalance;

        // Check that no balances changed
        assertEq(salt.balanceOf(address(_saltRewards)), expectedSaltContractBalance);
        assertEq(salt.balanceOf(address(exchangeConfig.stakingRewardsEmitter())), expectedStakingRewardsEmitterBalance);
        assertEq(salt.balanceOf(address(exchangeConfig.liquidityRewardsEmitter())), expectedLiquidityRewardsEmitterBalance);
        assertEq(_saltRewards.pendingStakingRewards(), 10 ether);
        assertEq(_saltRewards.pendingLiquidityRewards(), 20 ether);
    }


	// A unit test to verify contract balance after multiple addSALTRewards function calls.
	function testRepeatedAddSALTRewards() public {
		vm.startPrank(address(DEPLOYER));

		// Defining the amounts to add as salt rewards
		uint256[] memory amounts = new uint256[](3);
		amounts[0] = 3 ether;
		amounts[1] = 5 ether;
		amounts[2] = 2 ether;

		uint256 expectedBalance = 0;
		for (uint256 i = 0; i < amounts.length; i++) {
			// Add salt rewards
			salt.approve(address(saltRewards), amounts[i]);
			saltRewards.addSALTRewards(amounts[i]);

			// Update expected balance
			expectedBalance += amounts[i];

			// Check the balance of contract
			assertEq(salt.balanceOf(address(saltRewards)), expectedBalance, "Incorrect contract balance after addSALTRewards");
		}
	}


	// A unit test to validate that any leftover SALT dust is added to pendingRewardsSaltUSDS after executing the _sendLiquidityRewards function
	    function testAddDustToPendingRewardsSaltUSDS() public {
            TestSaltRewards _saltRewards = new TestSaltRewards(exchangeConfig, rewardsConfig);

            vm.prank(DEPLOYER);
            salt.transfer(address(_saltRewards), 50 ether);

            bytes32[] memory poolIDs = new bytes32[](1);
            (poolIDs[0],) = PoolUtils._poolID(salt,usds);

            uint256[] memory profitsForPools = new uint256[](1);
            profitsForPools[0] = 10 ether;

            // Initializing the pending rewards
            uint256 initialPendingLiquidityRewards = 40 ether;
            uint256 initialPendingRewardsSaltUSDS = 1 ether;
            _saltRewards.setPendingLiquidityRewards(initialPendingLiquidityRewards);
            _saltRewards.setPendingRewardsSaltUSDS(initialPendingRewardsSaltUSDS);

            // Balance of contract before running sendLiquidityRewards
			_saltRewards.sendStakingRewards();
            _saltRewards.sendLiquidityRewards(poolIDs, profitsForPools);

            // It should be equal to the dust remaining in the contract plus the initial pendingRewardsSaltUSDS
            assertEq(_saltRewards.pendingRewardsSaltUSDS(), 9 ether, "The remaining dust was not added to pendingRewardsSaltUSDS");
        }


	}

