// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";
import "./TestStakingRewards.sol";


// This test derives from StakingRewards itself as there are no underived instances of StakingRewards
contract SharedRewardsTest is Deployment
	{
    bytes32[] public poolIDs;

    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);

	TestStakingRewards public stakingRewards;


	constructor()
		{
		vm.prank(DEPLOYER);
		stakingRewards = new TestStakingRewards(exchangeConfig, poolsConfig, stakingConfig );
		}


    function setUp() public
    	{
		vm.prank(address(initialDistribution));
		salt.transfer(DEPLOYER, 100000000 ether);

    	IERC20 token1 = new TestERC20("TEST", 18);
		IERC20 token2 = new TestERC20("TEST", 18);

		vm.prank(address(dao));
		poolsConfig.whitelistPool(pools, token1, token2);

		vm.startPrank(DEPLOYER);
		salt.transfer( address(this), salt.balanceOf(DEPLOYER));
		vm.stopPrank();

		// Pools for testing
        poolIDs = new bytes32[](2);
        poolIDs[0] = PoolUtils.STAKED_SALT;
        (poolIDs[1],) = PoolUtils._poolID(token1, token2);

        // This contract approves max so that SALT rewards can be added
        salt.approve(address(stakingRewards), type(uint256).max);

        // Alice gets some salt and approves max
        salt.transfer(alice, 100 ether);
        vm.prank(alice);
        salt.approve(address(stakingRewards), type(uint256).max);

        // Bob gets some salt and approves max
        salt.transfer(bob, 100 ether);
        vm.prank(bob);
        salt.approve(address(stakingRewards), type(uint256).max);

        // Charlie gets some salt and approves max
        salt.transfer(charlie, 100 ether);
        vm.prank(charlie);
        salt.approve(address(stakingRewards), type(uint256).max);
    	}


	// A unit test that checks if a user can increase or decrease their share in a pool, considering the pool's validity, the cooldown period, and the amount being non-zero.
	function testIncreaseDecreaseShare() public {
	vm.startPrank(DEPLOYER);
	// Alice increases her share in pools[0] by 5 ether
	stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 5 ether, true);
	vm.stopPrank();

	// Check Alice's user share after increasing
	assertEq(stakingRewards.userShareForPool(alice, poolIDs[0]), 5 ether, "Alice's share should have increased" );

	// Alice tries to decrease her share by 6 ether, should fail due to exceeding user share
	vm.expectRevert("Cannot decrease more than existing user share");
	stakingRewards.externalDecreaseUserShare(alice, poolIDs[0], 6 ether, true);

	// Increase block time by 1 second
	vm.warp(block.timestamp + 1 );

	// Alice tries to decrease her share while in cooldown period, should fail
	vm.expectRevert("Must wait for the cooldown to expire");
	stakingRewards.externalDecreaseUserShare(alice, poolIDs[0], 4 ether, true);

	// Increase block time to pass the cooldown period
	uint256 cooldown = stakingConfig.modificationCooldown();
	vm.warp(block.timestamp + cooldown);

	// Alice decreases her share in pools[0] by 4 ether
	stakingRewards.externalDecreaseUserShare(alice, poolIDs[0], 4 ether, true);

	// Check Alice's user share after decreasing
	assertEq(stakingRewards.userShareForPool(alice, poolIDs[0]), 1 ether, "Alice's share should have decreased");
	}


	// A unit test that checks whether a user can successfully claim all rewards from multiple valid pools, and the correct amount of rewards are transferred to their wallet.
	function testClaimAllRewards() public {
	vm.startPrank(DEPLOYER);
    // Alice increases her share in pools[0] and pools[1] by 5 ether each
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 5 ether, true);
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 5 ether, true);
	vm.stopPrank();

    // Add rewards to the pools
    AddedReward[] memory addedRewards = new AddedReward[](2);
    addedRewards[0] = AddedReward(poolIDs[0], 10 ether);
    addedRewards[1] = AddedReward(poolIDs[1], 20 ether);
    stakingRewards.addSALTRewards(addedRewards);

    // Check Alice's pending rewards in both pools
    uint256 pendingRewardPool0 = stakingRewards.userPendingReward(alice, poolIDs[0]);
    uint256 pendingRewardPool1 = stakingRewards.userPendingReward(alice, poolIDs[1]);
    assertEq(pendingRewardPool0, 10 ether);
    assertEq(pendingRewardPool1, 20 ether);

    // Check Alice's SALT balance before claiming
    uint256 aliceSaltBalanceBefore = salt.balanceOf(alice);

    // Alice claims all rewards from both pools
    bytes32[] memory claimPools = new bytes32[](2);
    claimPools[0] = poolIDs[0];
    claimPools[1] = poolIDs[1];
    vm.prank(alice);
    stakingRewards.claimAllRewards(claimPools);

    // Check Alice's SALT balance after claiming
    uint256 aliceSaltBalanceAfter = salt.balanceOf(alice);
    assertEq(aliceSaltBalanceAfter, aliceSaltBalanceBefore + pendingRewardPool0 + pendingRewardPool1);
    }


	// A unit test that checks if the user cannot claim rewards from invalid pools.
	function testClaimRewardsFromInvalidPools() public {
    // Prepare invalid pool
    bytes32 invalidPool = bytes32(uint256(0xDEAD));

    // Try to claim rewards from an invalid pool
    // It shouldn't revert, but will not return any rewards
    bytes32[] memory invalidPools = new bytes32[](1);
    invalidPools[0] = invalidPool;
    stakingRewards.claimAllRewards(invalidPools);

    // Verify no rewards were claimed
    uint256 aliceSaltBalanceBefore = salt.balanceOf(alice);
    assertEq(aliceSaltBalanceBefore, 100 ether);
    }


	// A unit test that checks if adding SALT rewards to multiple valid pools updates the total rewards for each pool correctly and transfers the correct amount of SALT from the sender to the contract.
	function testAddSALTRewardsToMultiplePools() public {
    uint256 initialAliceSaltBalance = salt.balanceOf(alice);
    uint256 initialContractSaltBalance = salt.balanceOf(address(stakingRewards));

    uint256 expectedTotalRewardsPool0 = stakingRewards.totalRewards(poolIDs[0]) + 10 ether;
    uint256 expectedTotalRewardsPool1 = stakingRewards.totalRewards(poolIDs[1]) + 5 ether;

    AddedReward[] memory addedRewards = new AddedReward[](2);
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 10 ether});
    addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: 5 ether});

    vm.prank(alice);
    stakingRewards.addSALTRewards(addedRewards);

    uint256 expectedAliceSaltBalance = initialAliceSaltBalance - 15 ether;
    uint256 expectedContractSaltBalance = initialContractSaltBalance + 15 ether;

    assertEq(salt.balanceOf(alice), expectedAliceSaltBalance, "Alice's salt balance should decrease by 15 ether");
    assertEq(salt.balanceOf(address(stakingRewards)), expectedContractSaltBalance, "Contract's salt balance should increase by 15 ether");

    assertEq(stakingRewards.totalRewards(poolIDs[0]), expectedTotalRewardsPool0, "Total rewards for pool 0 should increase by 10 ether");
    assertEq(stakingRewards.totalRewards(poolIDs[1]), expectedTotalRewardsPool1, "Total rewards for pool 1 should increase by 5 ether");
    }


	// A unit test that checks if the user cannot add rewards to invalid pools.
	function testInvalidPoolCannotAddRewards() public {
    bytes32 invalidPool = bytes32(uint256(0xDEAD));
    uint256 initialTotalRewards = stakingRewards.totalRewardsForPools(poolIDs)[0];

    vm.expectRevert("Invalid pool");

    AddedReward[] memory addedRewards = new AddedReward[](2);
    addedRewards[0] = AddedReward({poolID: invalidPool, amountToAdd: 10 ether});
    stakingRewards.addSALTRewards( addedRewards );

    uint256 newTotalRewards = stakingRewards.totalRewardsForPools(poolIDs)[0];
    assertEq(initialTotalRewards, newTotalRewards, "Rewards should not be added to an invalid pool");
    }


	// A unit test that checks if totalSharesForPools function returns the correct total shares for each specified pool.
	function testTotalSharesForPools() public {
		vm.startPrank(DEPLOYER);
        // Alice increases shares for both pools
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, true);
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 5 ether, true);

        // Bob increases shares for both pools
        stakingRewards.externalIncreaseUserShare(bob, poolIDs[0], 20 ether, true);
        stakingRewards.externalIncreaseUserShare(bob, poolIDs[1], 15 ether, true);

        // Charlie increases shares for both pools
        stakingRewards.externalIncreaseUserShare(charlie, poolIDs[0], 30 ether, true);
        stakingRewards.externalIncreaseUserShare(charlie, poolIDs[1], 25 ether, true);
        vm.stopPrank();

        // Check total shares for pools
        uint256[] memory totalShares = stakingRewards.totalSharesForPools(poolIDs);
        assertEq(totalShares[0], 60 ether, "Total shares for pool 0 is incorrect");
        assertEq(totalShares[1], 45 ether, "Total shares for pool 1 is incorrect");
    }


	// A unit test that checks if stakingRewards.totalRewardsForPools function returns the correct total rewards for each specified pool.
	function testTotalRewardsForPools() public {
    // Add SALT rewards for each pool
    AddedReward[] memory addedRewards = new AddedReward[](2);
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 50 ether});
    addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: 75 ether});
    stakingRewards.addSALTRewards(addedRewards);

    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 25 ether});
    addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: 10 ether});
    stakingRewards.addSALTRewards(addedRewards);

    // Check total rewards for each pool
    uint256[] memory rewards = stakingRewards.totalRewardsForPools(poolIDs);

    assertEq(rewards[0], 75 ether, "Incorrect total rewards for STAKED_SALT pool");
    assertEq(rewards[1], 85 ether, "Incorrect total rewards for LP pool");
    }


	// A unit test that checks if userPendingReward function returns the correct pending rewards for a user in a specified pool.
	function testUserPendingReward() public {
	vm.prank(DEPLOYER);
    // Alice stakes 5 LP tokens in pools[0]
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, false);

    // Add 10 ether rewards to pools[0]
    salt.transfer(address(stakingRewards), 10 ether);
    AddedReward[] memory addedRewards = new AddedReward[](1);
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 10 ether});
    stakingRewards.addSALTRewards(addedRewards);

    // Check pending rewards for Alice in pools[0], should be 10 ether
    uint256 pendingRewards = stakingRewards.userPendingReward(alice, poolIDs[0]);
    assertEq(pendingRewards, 10 ether);

    // Add another 10 ether rewards to pools[0]
    salt.transfer(address(stakingRewards), 10 ether);
    stakingRewards.addSALTRewards(addedRewards);

    // Check pending rewards for Alice in pools[0], should be 20 ether
    pendingRewards = stakingRewards.userPendingReward(alice, poolIDs[0]);
    assertEq(pendingRewards, 20 ether);

    // Bob stakes 5 LP tokens in pools[0]
	vm.prank(DEPLOYER);
    stakingRewards.externalIncreaseUserShare(bob, poolIDs[0], 5 ether, false);

    // Add another 15 ether rewards to pools[0]
    // So Alice will get an additional 10 ether rewards and Bob will get an 5 ether rewards
    // as Alice has 10 ether share and bob has 5 ether rewards
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 15 ether});
    stakingRewards.addSALTRewards(addedRewards);

    // Check pending rewards for Alice in pools[0]
    pendingRewards = stakingRewards.userPendingReward(alice, poolIDs[0]);
    assertEq(pendingRewards, 30 ether);

    // Check pending rewards for Bob in pools[0]
    pendingRewards = stakingRewards.userPendingReward(bob, poolIDs[0]);
    assertEq(pendingRewards, 5 ether);
    }


	// A unit test that checks if userRewardsForPools function returns the correct pending rewards for a user in multiple specified pools.
	function testUserRewardsForPools() public {
	vm.startPrank(DEPLOYER);
    // Alice increases her share in pools[0] by 5 ether and pools[1] by 2 ether
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 5 ether, false);
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 2 ether, false);
	vm.stopPrank();

    // Add rewards to the pools
    AddedReward[] memory addedRewards = new AddedReward[](2);
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 10 ether});
    addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: 4 ether});
    stakingRewards.addSALTRewards(addedRewards);

    // Check pending rewards for Alice
    uint256[] memory expectedRewards = new uint256[](2);
    expectedRewards[0] = 10 ether;
    expectedRewards[1] = 4 ether;
    uint256[] memory actualRewards = stakingRewards.userRewardsForPools(alice, poolIDs);

    for (uint256 i = 0; i < actualRewards.length; i++)
        assertEq(actualRewards[i], expectedRewards[i], "Incorrect pending rewards for Alice");

    // Warp 1 day into the future
    vm.warp(block.timestamp + 1 days);

    // Add more rewards to the pools
    addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 20 ether});
    addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: 8 ether});
    stakingRewards.addSALTRewards(addedRewards);

    // Update expected rewards for Alice
    expectedRewards[0] = 30 ether;
    expectedRewards[1] = 12 ether;
    actualRewards = stakingRewards.userRewardsForPools(alice, poolIDs);

    for (uint256 i = 0; i < actualRewards.length; i++) {
        assertEq(actualRewards[i], expectedRewards[i], "Incorrect pending rewards for Alice after warp");
    }
    }


	// A unit test that checks if userShareForPools function returns the correct user share for a user in multiple specified pools.
	function testUserShareForPools() public {
	vm.startPrank(DEPLOYER);
    // Alice stakes in both pools
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, true);
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 20 ether, true);

    // Bob stakes in both pools
    stakingRewards.externalIncreaseUserShare(bob, poolIDs[0], 15 ether, true);
    stakingRewards.externalIncreaseUserShare(bob, poolIDs[1], 25 ether, true);
	vm.stopPrank();

    // Check user shares for both Alice and Bob
    uint256[] memory aliceShares = stakingRewards.userShareForPools(alice, poolIDs);
    uint256[] memory bobShares = stakingRewards.userShareForPools(bob, poolIDs);

    // Assert Alice's shares
    assertEq(aliceShares[0], 10 ether, "Alice's share in pool 0 should be 10 ether");
    assertEq(aliceShares[1], 20 ether, "Alice's share in pool 1 should be 20 ether");

    // Assert Bob's shares
    assertEq(bobShares[0], 15 ether, "Bob's share in pool 0 should be 15 ether");
    assertEq(bobShares[1], 25 ether, "Bob's share in pool 1 should be 25 ether");
    }


	// A unit test that checks if userCooldowns function returns the correct cooldown time remaining for a user in multiple specified pools.
	function testUserCooldowns() public {
		vm.startPrank(DEPLOYER);
        // Alice increases her share for both pools which will trigger the cooldown
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, true);
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 5 ether, true);
		vm.stopPrank();

        // Get initial cooldowns for Alice in both pools
        uint256[] memory cooldownsInitial = stakingRewards.userCooldowns(alice, poolIDs);

        // Check if the initial cooldowns are equal to the expected modification cooldown
        uint256 expectedCooldown = stakingConfig.modificationCooldown();
        assertEq(cooldownsInitial[0], expectedCooldown, "Initial cooldown for pool 0 incorrect");
        assertEq(cooldownsInitial[1], expectedCooldown, "Initial cooldown for pool 1 incorrect");

        // Warp time forward by half the cooldown duration
        uint256 halfCooldown = expectedCooldown / 2;
        vm.warp(block.timestamp + halfCooldown);

        // Get the updated cooldowns for Alice in both pools
        uint256[] memory cooldownsAfterWarp = stakingRewards.userCooldowns(alice, poolIDs);

        // Check if the updated cooldowns are correct after warping time
        assertEq(cooldownsAfterWarp[0], halfCooldown, "Cooldown for pool 0 after warp incorrect");
        assertEq(cooldownsAfterWarp[1], halfCooldown, "Cooldown for pool 1 after warp incorrect");

		vm.prank(DEPLOYER);
		vm.expectRevert( "Must wait for the cooldown to expire" );
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, true);

        // Warp time forward to the end of the cooldown
        vm.warp(block.timestamp + halfCooldown);

		vm.prank(DEPLOYER);
        stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, true);

        // Get the final cooldowns for Alice in both pools
        uint256[] memory cooldownsFinal = stakingRewards.userCooldowns(alice, poolIDs);

        // Check if the final cooldowns are 0, indicating that the cooldown has expired
        assertEq(cooldownsFinal[0], expectedCooldown, "Final cooldown for pool 0 incorrect");
        assertEq(cooldownsFinal[1], 0, "Final cooldown for pool 1 incorrect");
    }


	// A unit test where alice, bob and charlie have multiple shares and share rewards
	function testMultipleSharesAndRewards() public {
		// Initial balances
		uint256 initialSaltAlice = salt.balanceOf(alice);
		uint256 initialSaltBob = salt.balanceOf(bob);
		uint256 initialSaltCharlie = salt.balanceOf(charlie);

		// Alice, Bob, and Charlie increase their shares
		vm.startPrank(DEPLOYER);
		stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 5 ether, false);
		stakingRewards.externalIncreaseUserShare(bob, poolIDs[0], 3 ether, false);
		stakingRewards.externalIncreaseUserShare(charlie, poolIDs[0], 2 ether, false);
		vm.stopPrank();

		// Add SALT rewards
		AddedReward[] memory addedRewards = new AddedReward[](1);
		addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 100 ether});
		stakingRewards.addSALTRewards(addedRewards);

		// Check initial rewards for Alice, Bob, and Charlie
		uint256 aliceReward = stakingRewards.userPendingReward(alice, poolIDs[0]);
		uint256 bobReward = stakingRewards.userPendingReward(bob, poolIDs[0]);
		uint256 charlieReward = stakingRewards.userPendingReward(charlie, poolIDs[0]);

		assertEq(aliceReward, 50 ether);
		assertEq(bobReward, 30 ether);
		assertEq(charlieReward, 20 ether);

		// Warp the time forward
		vm.warp(block.timestamp + 60 days);

		// Add more SALT rewards
		addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: 200 ether});
		stakingRewards.addSALTRewards(addedRewards);

		// Check updated rewards for Alice, Bob, and Charlie
		aliceReward = stakingRewards.userPendingReward(alice, poolIDs[0]);
		bobReward = stakingRewards.userPendingReward(bob, poolIDs[0]);
		charlieReward = stakingRewards.userPendingReward(charlie, poolIDs[0]);

		assertEq(aliceReward, 150 ether);
		assertEq(bobReward, 90 ether);
		assertEq(charlieReward, 60 ether);

		// Alice, Bob, and Charlie claim all rewards
		bytes32[] memory poolsToClaim = new bytes32[](1);
		poolsToClaim[0] = poolIDs[0];
		vm.prank(alice);
		stakingRewards.claimAllRewards(poolsToClaim);
		vm.prank(bob);
		stakingRewards.claimAllRewards(poolsToClaim);
		vm.prank(charlie);
		stakingRewards.claimAllRewards(poolsToClaim);

		// Check that Alice, Bob, and Charlie have no pending rewards after claiming
		aliceReward = stakingRewards.userPendingReward(alice, poolIDs[0]);
		bobReward = stakingRewards.userPendingReward(bob, poolIDs[0]);
		charlieReward = stakingRewards.userPendingReward(charlie, poolIDs[0]);

		assertEq(aliceReward, 0);
		assertEq(bobReward, 0);
		assertEq(charlieReward, 0);

		// Make sure the rewarded amount is what was expected
		uint256 rewardedSaltAlice = salt.balanceOf(alice) - initialSaltAlice;
		uint256 rewardedSaltBob = salt.balanceOf(bob) - initialSaltBob;
		uint256 rewardedSaltCharlie = salt.balanceOf(charlie) - initialSaltCharlie;

		assertEq(rewardedSaltAlice, 150 ether);
		assertEq(rewardedSaltBob, 90 ether);
		assertEq(rewardedSaltCharlie, 60 ether);
		}


	// A unit test that checks if the contract correctly updates the total rewards and transfers the correct amount of SALT tokens when adding rewards to multiple pools with varying amounts.
	function testAddSALTRewards() public {
		uint256 initialSaltBalanceAlice = salt.balanceOf(address(alice));

		uint256[] memory rewardsToAdd = new uint256[](2);
		rewardsToAdd[0] = 10 ether;
		rewardsToAdd[1] = 5 ether;

		AddedReward[] memory addedRewards = new AddedReward[](2);
		addedRewards[0] = AddedReward({poolID: poolIDs[0], amountToAdd: rewardsToAdd[0]});
		addedRewards[1] = AddedReward({poolID: poolIDs[1], amountToAdd: rewardsToAdd[1]});

		uint256[] memory expectedTotalRewards = new uint256[](2);
		expectedTotalRewards[0] = stakingRewards.totalRewards(poolIDs[0]) + rewardsToAdd[0];
		expectedTotalRewards[1] = stakingRewards.totalRewards(poolIDs[1]) + rewardsToAdd[1];

		vm.prank(alice);
		stakingRewards.addSALTRewards(addedRewards);

		uint256[] memory actualTotalRewards = stakingRewards.totalRewardsForPools(poolIDs);
		assertEq(actualTotalRewards[0], expectedTotalRewards[0], "Total rewards for pool[0] are incorrect after adding SALT rewards");
		assertEq(actualTotalRewards[1], expectedTotalRewards[1], "Total rewards for pool[1] are incorrect after adding SALT rewards");

		uint256 expectedSaltBalanceAlice = initialSaltBalanceAlice - (rewardsToAdd[0] + rewardsToAdd[1]);
		assertEq(salt.balanceOf(address(alice)), expectedSaltBalanceAlice, "SALT balance is incorrect after adding rewards");
		}


	// A unit test that checks if the user cannot claim rewards from pools with zero pending rewards.
	function testCannotClaimRewardsFromZeroPendingRewards() public {
		vm.startPrank(DEPLOYER);

		// Alice increases her share in both pools
		stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 10 ether, false);
		stakingRewards.externalIncreaseUserShare(alice, poolIDs[1], 10 ether, false);
		vm.stopPrank();

		// Warp time forward to simulate rewards generation
		vm.warp(block.timestamp + 10 days);

		// Ensure that pending rewards are zero for Alice
		assertEq(stakingRewards.userPendingReward(alice, poolIDs[0]), 0, "Initial pending rewards should be zero[0]" );
		assertEq(stakingRewards.userPendingReward(alice, poolIDs[1]), 0, "Initial pending rewards should be zero[1]" );

		// Attempt to claim rewards for Alice, expect zero pending rewards
		uint256 initialSaltBalanceAlice = salt.balanceOf(address(alice));
		vm.prank(alice);
		stakingRewards.claimAllRewards(poolIDs);

		assertEq(salt.balanceOf(address(alice)), initialSaltBalanceAlice, "No rewards should be claimed" );
		}


	// A unit test that checks if the totalSharesForPools, stakingRewards.totalRewardsForPools, userRewardsForPools, and userShareForPools functions return empty arrays when called with empty input arrays.
	function testEmptyInputArrays() public {
		bytes32[] memory emptyPools = new bytes32[](0);

		uint256[] memory totalShares = stakingRewards.totalSharesForPools(emptyPools);
//		uint256[] memory totalRewards = stakingRewards.totalRewardsForPools(emptyPools);
		uint256[] memory userRewards = stakingRewards.userRewardsForPools(alice, emptyPools);
		uint256[] memory userShares = stakingRewards.userShareForPools(alice, emptyPools);

		assertEq(totalShares.length, 0, "totalShares.length shoudl be zero" );
//		assertEq(stakingRewards.totalRewards.length, 0, "totalRewards.length should be zero" );
		assertEq(userRewards.length, 0, "userRewards.length should be zero" );
		assertEq(userShares.length, 0, "userShares.length should be zero" );
		}


	// A unit test that checks if the userCooldowns function returns an array of 0s for cooldown times when the user is not part of any of the specified pools.
	function testUserCooldownsWhenNotInPools() public {
    // Define the pools to check
    bytes32[] memory testPools = new bytes32[](2);
    testPools[0] = poolIDs[0];
    testPools[1] = poolIDs[1];

    // Get the user's cooldowns for the specified pools
    uint256[] memory cooldowns = stakingRewards.userCooldowns(alice, testPools);

    // Verify that the cooldown times are all 0
    for (uint256 i = 0; i < cooldowns.length; i++)
    	assertEq(cooldowns[i], 0, "Cooldown time should be 0 when the user is not part of any of the specified pools");
    }


	// A unit test that checks the system's handling of multiple users (Alice, Bob, and Charlie) performing a sequence of actions such as increasing and decreasing shares, adding rewards, and claiming rewards on a shared pool, and validates the correct updating of shares, rewards, and the pool's state.
	function testMultipleUsersActions() public {

	uint256 initialSaltBalanceAlice = salt.balanceOf(address(alice));
	uint256 initialSaltBalanceBob = salt.balanceOf(address(bob));
	uint256 initialSaltBalanceCharlie = salt.balanceOf(address(charlie));

    // Alice increases share by 20 ether
	vm.startPrank(DEPLOYER);
    stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 20 ether, false);

    // Bob increases share by 20 ether
    stakingRewards.externalIncreaseUserShare(bob, poolIDs[0], 20 ether, false);

    // Charlie increases share by 40 ether
    stakingRewards.externalIncreaseUserShare(charlie, poolIDs[0], 40 ether, false);
	vm.stopPrank();

    // Warp time forward by one day
    vm.warp(block.timestamp + 1 days);

	uint256 startingBalance = salt.balanceOf( address(stakingRewards) );

    AddedReward[] memory addedRewards = new AddedReward[](1);
    addedRewards[0] = AddedReward(poolIDs[0], 40 ether);
    stakingRewards.addSALTRewards(addedRewards);

	uint256 added = salt.balanceOf(address(stakingRewards)) - startingBalance;
	assertEq( added, 40 ether );

    // Alice decreases share by 10 ether
    stakingRewards.externalDecreaseUserShare(alice, poolIDs[0], 10 ether, false);

	startingBalance = salt.balanceOf( address(stakingRewards) );

    // Bob claims rewards
    // Bob should claim 10
    vm.prank(bob);
    stakingRewards.claimAllRewards(poolIDs);

	uint256 removed = startingBalance - salt.balanceOf(address(stakingRewards));
	assertEq( removed, 10 ether );

    // Bob decreases share by 10 ether
    stakingRewards.externalDecreaseUserShare(bob, poolIDs[0], 10 ether, false);

	// Add another 60 rewards
    addedRewards[0] = AddedReward(poolIDs[0], 60 ether);
    stakingRewards.addSALTRewards(addedRewards);

    // Warp time forward by 15 seconds
    vm.warp(block.timestamp + 15 seconds);

    // Charlie claims rewards
    vm.prank(charlie);
    stakingRewards.claimAllRewards(poolIDs);

    // Check pool state
    uint256 poolTotalShares = stakingRewards.totalShares(poolIDs[0]);
    uint256 poolTotalRewards = stakingRewards.totalRewards(poolIDs[0]);
    assertEq(poolTotalShares, 60 ether, "Incorrect total shares for pool");
    assertEq(poolTotalRewards, 90 ether, "Incorrect total rewards for pool");

    // Check Alice's state
    assertEq(stakingRewards.userShareForPool(alice,poolIDs[0]), 10 ether, "Incorrect share for Alice");
//    assertEq(aliceShareInfo.virtualRewards, 0, "Incorrect virtual rewards for Alice");

    // Check Bob's state
    assertEq(stakingRewards.userShareForPool(bob,poolIDs[0]), 10 ether, "Incorrect share for Bob");
//    assertEq(bobShareInfo.virtualRewards, 5 ether, "Incorrect virtual rewards for Bob");

    // Check Charlie's state
    assertEq(stakingRewards.userShareForPool(charlie,poolIDs[0]), 40 ether, "Incorrect share for Charlie");
//    assertEq(charlieShareInfo.virtualRewards, 60 ether, "Incorrect virtual rewards for Charlie");

    // Check pending rewards
	assertEq( stakingRewards.userPendingReward(alice, poolIDs[0]), 15 ether, "Incorrect pending reward for alice" );
	assertEq( stakingRewards.userPendingReward(bob, poolIDs[0]), 10 ether, "Incorrect pending reward for bob" );
	assertEq( stakingRewards.userPendingReward(charlie, poolIDs[0]), 0 ether, "Incorrect pending reward for charlie" );

	// Check withdrawn rewards
	uint256 saltBalanceAlice = salt.balanceOf(address(alice));
	uint256 saltBalanceBob = salt.balanceOf(address(bob));
	uint256 saltBalanceCharlie = salt.balanceOf(address(charlie));

	assertEq( saltBalanceAlice - initialSaltBalanceAlice, 5 ether, "Incorrect withdrawn rewards for alice" );
	assertEq( saltBalanceBob - initialSaltBalanceBob, 10 ether, "Incorrect withdrawn rewards for bob" );
	assertEq( saltBalanceCharlie - initialSaltBalanceCharlie, 60 ether, "Incorrect withdrawn rewards for charlie" );
    }


    // A unit test that checks if the addSALTRewards function limits the rewards to the amount of SALT held by the sender.
    function testAddSALTRewardsLimit() public {
        uint256 aliceBalanceBefore = salt.balanceOf(alice);
        uint256 excessiveRewards = aliceBalanceBefore + 1 ether;

        // Prepare excessive rewards array
        AddedReward[] memory addedRewards = new AddedReward[](1);
        addedRewards[0] = AddedReward( poolIDs[1], excessiveRewards );

        // Make alice the caller
        vm.startPrank(alice);

        // Expect revert because the rewards exceed the SALT balance of Alice
        vm.expectRevert( "ERC20: transfer amount exceeds balance" );
        stakingRewards.addSALTRewards(addedRewards);

        // Verify the SALT balance of Alice hasn't changed
        uint256 aliceBalanceAfter = salt.balanceOf(alice);
        assertEq(aliceBalanceBefore, aliceBalanceAfter, "Alice's balance should not have changed");
    }


	// A unit test that checks if userPendingReward function returns zero for the users and pools with zero share and zero totalReward.
	function testUserPendingRewardWithZeroShareAndZeroRewards() public {
        // Check pending rewards for Alice in pools[0], should be 0 as the user share and total rewards is 0
        uint256 pendingRewards = stakingRewards.userPendingReward(alice, poolIDs[0]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");

        // Check pending rewards for Bob in pools[0], should be 0 as the user share and total rewards is 0
        pendingRewards = stakingRewards.userPendingReward(bob, poolIDs[0]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");

        // Check pending rewards for Charlie in pools[0], should be 0 as the user share and total rewards is 0
        pendingRewards = stakingRewards.userPendingReward(charlie, poolIDs[0]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");

        // Check pending rewards for Alice in pools[1], should be 0 as the user share and total rewards is 0
        pendingRewards = stakingRewards.userPendingReward(alice, poolIDs[1]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");

        // Check pending rewards for Bob in pools[1], should be 0 as the user share and total rewards is 0
        pendingRewards = stakingRewards.userPendingReward(bob, poolIDs[1]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");

        // Check pending rewards for Charlie in pools[1], should be 0 as the user share and total rewards is 0
        pendingRewards = stakingRewards.userPendingReward(charlie, poolIDs[1]);
        assertEq(pendingRewards, 0, "Pending Rewards should be zero");
    }


	// A unit test that confirms that rewards cannot be claimed from pools where the user has no shares.
	function testClaimRewardsWithNoShares() public {
            vm.prank(DEPLOYER);
            // Alice increases her share in pools[0] by 5 ether
            stakingRewards.externalIncreaseUserShare(alice, poolIDs[0], 5 ether, true);

            // Add rewards to the pools
            AddedReward[] memory addedRewards = new AddedReward[](2);
            addedRewards[0] = AddedReward(poolIDs[0], 10 ether);
            addedRewards[1] = AddedReward(poolIDs[1], 20 ether);
            stakingRewards.addSALTRewards(addedRewards);

            uint256 aliceSaltBalanceBeforeClaim = salt.balanceOf(alice);

            // Alice tries to claim all rewards from both pools
            bytes32[] memory claimPools = new bytes32[](2);
            claimPools[0] = poolIDs[0];
            claimPools[1] = poolIDs[1];
            vm.prank(alice);
            stakingRewards.claimAllRewards(claimPools);
            uint256 aliceSaltBalanceAfterClaim = salt.balanceOf(alice);

            // Verify that rewards were claimed from pool[0] where Alice had shares
            assertEq(aliceSaltBalanceAfterClaim, aliceSaltBalanceBeforeClaim + 10 ether, "Alice should have claimed rewards");

            // Alice tries to claim rewards from pools[1] where she has no shares.
            // It shouldn't revert, but will not return any rewards
            claimPools = new bytes32[](1);
            claimPools[0] = poolIDs[1];
            stakingRewards.claimAllRewards(claimPools);

            // Verify no rewards were claimed
            aliceSaltBalanceAfterClaim = salt.balanceOf(alice);
            assertEq(aliceSaltBalanceAfterClaim, aliceSaltBalanceBeforeClaim + 10 ether, "Alice should not be able to claim rewards");
        }


	// A unit test that checks if the constructor rejects zero addresses for the configuration contracts and token.
    function testConstructorRejectsZeroAddresses() public {
        vm.expectRevert("_exchangeConfig cannot be address(0)");
        stakingRewards = new TestStakingRewards(IExchangeConfig(address(0)), poolsConfig, stakingConfig);

        vm.expectRevert("_poolsConfig cannot be address(0)");
        stakingRewards = new TestStakingRewards(exchangeConfig, IPoolsConfig(address(0)), stakingConfig);

        vm.expectRevert("_stakingConfig cannot be address(0)");
        stakingRewards = new TestStakingRewards(exchangeConfig, poolsConfig, IStakingConfig(address(0)));
    }
	}
