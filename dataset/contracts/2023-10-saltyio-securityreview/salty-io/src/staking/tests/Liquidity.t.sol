// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";


contract LiquidityTest is Deployment
	{
    bytes32[] public poolIDs;
    bytes32 public pool1;
    bytes32 public pool2;

    IERC20 public token1;
    IERC20 public token2;
    IERC20 public token3;

    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);


    function setUp() public
    	{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();


		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);

    	token1 = new TestERC20("TEST", 18);
		token2 = new TestERC20("TEST", 18);
		token3 = new TestERC20("TEST", 18);

        (pool1,) = PoolUtils._poolID(token1, token2);
        (pool2,) = PoolUtils._poolID(token2, token3);

        poolIDs = new bytes32[](2);
        poolIDs[0] = pool1;
        poolIDs[1] = pool2;

        // Whitelist the _pools
		vm.startPrank( address(dao) );
        poolsConfig.whitelistPool(pools, token1, token2);
        poolsConfig.whitelistPool(pools, token2, token3);
        vm.stopPrank();

		vm.prank(DEPLOYER);
		salt.transfer( address(this), 100000 ether );


        salt.approve(address(liquidity), type(uint256).max);

        // Alice gets some salt and pool lps and approves max to staking
        token1.transfer(alice, 1000 ether);
        token2.transfer(alice, 1000 ether);
        token3.transfer(alice, 1000 ether);
        vm.startPrank(alice);
        token1.approve(address(liquidity), type(uint256).max);
        token2.approve(address(liquidity), type(uint256).max);
        token3.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();

        // Bob gets some salt and pool lps and approves max to staking
        token1.transfer(bob, 1000 ether);
        token2.transfer(bob, 1000 ether);
        token3.transfer(bob, 1000 ether);
        vm.startPrank(bob);
        token1.approve(address(liquidity), type(uint256).max);
        token2.approve(address(liquidity), type(uint256).max);
        token3.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();


        // Charlie gets some salt and pool lps and approves max to staking
        token1.transfer(charlie, 1000 ether);
        token2.transfer(charlie, 1000 ether);
        token3.transfer(charlie, 1000 ether);
        vm.startPrank(charlie);
        token1.approve(address(liquidity), type(uint256).max);
        token2.approve(address(liquidity), type(uint256).max);
        token3.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();


        // DAO gets some salt and pool lps and approves max to staking
        token1.transfer(address(dao), 1000 ether);
        token2.transfer(address(dao), 1000 ether);
        token3.transfer(address(dao), 1000 ether);
        vm.startPrank(address(dao));
        token1.approve(address(liquidity), type(uint256).max);
        token2.approve(address(liquidity), type(uint256).max);
        token3.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();
    	}


	// Convenience function
	function totalSharesForPool( bytes32 poolID ) public view returns (uint256)
		{
		bytes32[] memory _pools2 = new bytes32[](1);
		_pools2[0] = poolID;

		return liquidity.totalSharesForPools(_pools2)[0];
		}


	// A unit test where a user deposits liquidity and increases share for a valid pool. Checks that the user's share of the pool, the total pool share increases appropriately, and that tokens were trasnferred properly
	function testAddLiquidityAndIncreaseShare() public {
		// Check initial balances
		assertEq(liquidity.userShareForPool(alice, pool1), 0, "Alice's initial liquidity share should be zero");
		assertEq(totalSharesForPool( pool1 ), 0, "Pool should initially have zero liquidity share" );
		assertEq( token1.balanceOf( address(pools)), 0, "liquidity should start with zero token1" );
        assertEq( token2.balanceOf( address(pools)), 0, "liquidity should start with zero token2" );

		uint256 addedAmount1 = 10 ether;
		uint256 addedAmount2 = 20 ether;

		// Have alice add liquidity
		vm.prank(alice);
		(uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, addedAmount1, addedAmount2, 0 ether, block.timestamp, false );
		assertEq( addedAmountA, addedAmount1, "Tokens were not deposited into the pool as expected" );
		assertEq( addedAmountB, addedAmount2, "Tokens were not deposited into the pool as expected" );

		// Check that the user's share of the pool has increased appropriately
		assertEq(liquidity.userShareForPool(alice, poolIDs[0]), addedLiquidity, "Alice's share did not increase as expected" );

		// Check that the total shares for the pool has increased appropriately
		assertEq(totalSharesForPool(poolIDs[0]), addedLiquidity, "Total pool stake did not increase as expected" );

		// Check that the contract balance has increased by the amount of the added tokens
		assertEq( token1.balanceOf( address(pools)), addedAmount1, "Tokens were not deposited into the pool as expected" );
        assertEq( token2.balanceOf( address(pools)), addedAmount2, "Tokens were not deposited into the pool as expected" );
	}


	// A unit test where a user withdraws a valid amount of liquidity from a pool. Checks that the user's share of the pool decreases appropriately and the tokens are transferred back.
	function testValidWithdrawLiquidityAndClaim() public {
		// Check initial balances
		assertEq(liquidity.userShareForPool(alice, pool1), 0, "Alice's initial liquidity share should be zero");
		assertEq(totalSharesForPool( pool1 ), 0, "Pool should initially have zero liquidity share" );
		assertEq( token1.balanceOf( address(pools)), 0, "liquidity should start with zero token1" );
        assertEq( token2.balanceOf( address(pools)), 0, "liquidity should start with zero token2" );

		uint256 addedAmount1 = 10 ether;
		uint256 addedAmount2 = 20 ether;

		// Have alice add liquidity
		vm.prank(alice);
		(uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, addedAmount1, addedAmount2, 0 ether, block.timestamp, false );
		assertEq(liquidity.userShareForPool(alice, pool1), addedLiquidity, "Alice's share should have increased" );

		// Check that the contract balance has increased by the amount of the added tokens
		assertEq( token1.balanceOf( address(pools)), addedAmount1, "Tokens were not deposited into the pool as expected" );
        assertEq( token2.balanceOf( address(pools)), addedAmount2, "Tokens were not deposited into the pool as expected" );

		vm.warp( block.timestamp + 1 days ); // overcome cooldown

		// Alice unstakes half her liquidity
		vm.prank(alice);
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidity / 2, 0, 0, block.timestamp);

		// Check that Alice's liquidity share has decreased
		assertEq(liquidity.userShareForPool(alice, pool1), addedLiquidity / 2, "Alice's share should have decreased" );

		// Check that Alice's token balance has increased appropriately
		assertEq( token1.balanceOf( address(pools)), addedAmountA / 2, "alice shoudl have reclaimed half of token1" );
        assertEq( token2.balanceOf( address(pools)), addedAmountB / 2, "alice shoudl have reclaimed half of token2" );

		// Check that the contract balance has decreased by the amount of the added withdrawn
		assertEq( token1.balanceOf( address(pools)), addedAmount1 / 2, "Tokens were not withdrawn from the pool as expected" );
        assertEq( token2.balanceOf( address(pools)), addedAmount2 / 2, "Tokens were not withdrawn from the pool as expected" );
	}



	// A unit test to check that users without exchange access cannot addLiquidityAndIncreaseShare
	function testUserWithoutAccess() public
		{
		vm.expectRevert( "Sender does not have exchange access" );
		vm.prank(address(0xDEAD));
		liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 10 ether, 0 ether, block.timestamp, false );
		}




	// A unit test where the DAO attempts to withdraw liquidity from the pool. The function should reject this operation and not modify the the liquidity share.
	function testWithdrawLiquidityFromDAO() public {

		// Have the DAO add liquidity
		vm.startPrank(address(dao));
		(,, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 10 ether, 0 ether, block.timestamp, false );
		assertEq(liquidity.userShareForPool(address(dao), pool1), addedLiquidity, "DAO's share should have increased" );

		// DAO attempts to withdraw liquidity
		vm.expectRevert("DAO is not allowed to withdraw liquidity" );
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidity, 0, 0, block.timestamp);
		assertEq(liquidity.userShareForPool(address(dao), pool1), addedLiquidity, "DAO's share should not change after failed unstake attempt");
		vm.stopPrank();
	}


	// A unit test where a user attempts to withdraw more liquidity than they have deposited. The function should reject this operation and not modify the user's share of the pool.
	function tesWithdrawingMoreThanDeposited() public {
		// Have alice add liquidity
		vm.startPrank(alice);
		(,, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 20 ether, 0 ether, block.timestamp, false );

		// Alice attempts to withdraw more than she deposited
		vm.expectRevert("Cannot decrease more than existing user share" );
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidity + 1, 0, 0, block.timestamp);
		assertEq(liquidity.userShareForPool(alice, poolIDs[1]), addedLiquidity, "User's share should not change after failed unstake attempt");
	}


	// A unit test where a user tries to withdraw liquidity before the cooldown period has expired. This test ensures that the contract rejects the unstake and does not modify the user's share of the pool.
	function testUnstakeBeforeCooldown() public {
		// Have alice add liquidity
		vm.startPrank(alice);
		(,, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 20 ether, 0 ether, block.timestamp, false );

		// Alice attempts to withdraw more than she deposited
		vm.expectRevert("Must wait for the cooldown to expire" );
		liquidity.withdrawLiquidityAndClaim(token1, token2, addedLiquidity, 0, 0, block.timestamp);

		// Make sure none of the share was removed
		assertEq(liquidity.userShareForPool(alice, pool1), addedLiquidity, "User's share should not change after failed unstake attempt");
    }


	function check1( uint256 shareA, uint256 shareB, uint256 shareC, uint256 rA, uint256 rB, uint256 rC ) public
		{
		assertEq( liquidity.userShareForPool(alice, pool2), shareA, "Share A incorrect" );
		assertEq( liquidity.userShareForPool(bob, pool2), shareB, "Share B incorrect" );
		assertEq( liquidity.userShareForPool(charlie, pool2), shareC, "Share C incorrect" );

		assertEq( liquidity.userPendingReward( alice, pool2 ), rA, "Incorrect pending rewards A" );
        assertEq( liquidity.userPendingReward( bob, pool2 ), rB, "Incorrect pending rewards B" );
        assertEq( liquidity.userPendingReward( charlie, pool2 ), rC, "Incorrect pending rewards C" );
		}


	function check2( uint256 sA, uint256 sB, uint256 sC ) public
		{
		assertEq( salt.balanceOf(alice), sA, "SALT A incorrect" );
		assertEq( salt.balanceOf(bob), sB, "SALT B incorrect" );
		assertEq( salt.balanceOf(charlie), sC, "SALT C incorrect" );
		}


    // A unit test with adding and withdrawing liquidity from multiple users: Alice, Bob and Charlie each adding liquidity, claiming and withdrawing, with rewards being interleaved between each user action as well.  addSALTRewards should be used to add the rewards with some amount of rewards (between 10 and 100 SALT) being added after each user interaction.
	function testMultipleUserStakingClaiming() public {

		uint256 startingSaltA = salt.balanceOf(alice);
		uint256 startingSaltB = salt.balanceOf(bob);
        uint256 startingSaltC = salt.balanceOf(charlie);

		assertEq( startingSaltA, 0, "Starting SALT A not zero" );
		assertEq( startingSaltB, 0, "Starting SALT B not zero" );
        assertEq( startingSaltC, 0, "Starting SALT C not zero" );

		// Alice adds 50 ether of token2 and token3
		vm.prank(alice);
		liquidity.addLiquidityAndIncreaseShare( token2, token3, 50 ether, 50 ether, 0, block.timestamp, false );
		check1( 50 ether, 0 ether, 0 ether, 0 ether, 0 ether, 0 ether );
		check2( 0 ether, 0 ether, 0 ether );
		AddedReward[] memory rewards = new AddedReward[](1);
		rewards[0] = AddedReward(pool2, 50 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 50 ether, 0 ether, 0 ether, 50 ether, 0 ether, 0 ether );
		check2( 0 ether, 0 ether, 0 ether );

		// Bob adds 10/10 ether
		vm.prank(bob);
		liquidity.addLiquidityAndIncreaseShare( token2, token3, 10 ether, 10 ether, 0, block.timestamp, false );
		check1( 50 ether, 10 ether, 0 ether, 50 ether, 0 ether, 0 ether );
		check2( 0 ether, 0 ether, 0 ether );
		rewards[0] = AddedReward(pool2, 30 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 50 ether, 10 ether, 0 ether, 75 ether, 5 ether, 0 ether );
		check2( 0 ether, 0 ether, 0 ether );

		// Alice claims
		vm.prank(alice);
		liquidity.claimAllRewards(poolIDs);
		check1( 50 ether, 10 ether, 0 ether, 0 ether, 5 ether, 0 ether );
		check2( 75 ether, 0 ether, 0 ether );
		rewards[0] = AddedReward(pool2, 30 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 50 ether, 10 ether, 0 ether, 25 ether, 10 ether, 0 ether );
		check2( 75 ether, 0 ether, 0 ether );

		// Charlie adds 40/40 ether
		vm.prank(charlie);
		liquidity.addLiquidityAndIncreaseShare( token2, token3, 40 ether, 40 ether, 0, block.timestamp, false );
		check1( 50 ether, 10 ether, 40 ether, 25 ether, 10 ether, 0 ether );
		check2( 75 ether, 0 ether, 0 ether );
		rewards[0] = AddedReward(pool2, 100 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 50 ether, 10 ether, 40 ether, 75 ether, 20 ether, 40 ether );
		check2( 75 ether, 0 ether, 0 ether );

		// Alice unstakes 10
		vm.prank(alice);
		liquidity.withdrawLiquidityAndClaim(token2, token3, 10 ether, 0, 0, block.timestamp);
		check1( 40 ether, 10 ether, 40 ether, 60 ether, 20 ether, 40 ether );
		check2( 90 ether, 0 ether, 0 ether );
		rewards[0] = AddedReward(pool2, 90 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 40 ether, 10 ether, 40 ether, 100 ether, 30 ether, 80 ether );
		check2( 90 ether, 0 ether, 0 ether );

		// Bob claims
		vm.prank(bob);
		liquidity.claimAllRewards(poolIDs);
		check1( 40 ether, 10 ether, 40 ether, 100 ether, 0 ether, 80 ether );
		check2( 90 ether, 30 ether, 0 ether );
		rewards[0] = AddedReward(pool2, 90 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 40 ether, 10 ether, 40 ether, 140 ether, 10 ether, 120 ether );
		check2( 90 ether, 30 ether, 0 ether );

		// Charlie claims
		vm.prank(charlie);
		liquidity.claimAllRewards(poolIDs);
		check1( 40 ether, 10 ether, 40 ether, 140 ether, 10 ether, 0 ether );
		check2( 90 ether, 30 ether, 120 ether );
		rewards[0] = AddedReward(pool2, 180 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 40 ether, 10 ether, 40 ether, 220 ether, 30 ether, 80 ether );
		check2( 90 ether, 30 ether, 120 ether );

		// Alice adds 100/100 ether
		vm.prank(alice);
		liquidity.addLiquidityAndIncreaseShare( token2, token3, 100 ether, 100 ether, 0, block.timestamp, false );
		check1( 140 ether, 10 ether, 40 ether, 220 ether, 30 ether, 80 ether );
		check2( 90 ether, 30 ether, 120 ether );
		rewards[0] = AddedReward(pool2, 190 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 140 ether, 10 ether, 40 ether, 360 ether, 40 ether, 120 ether );
		check2( 90 ether, 30 ether, 120 ether );

		// Charlie unstakes all
		vm.prank(charlie);
		liquidity.withdrawLiquidityAndClaim( token2, token3, 40 ether, 0, 0, block.timestamp);
		check1( 140 ether, 10 ether, 0 ether, 360 ether, 40 ether, 0 ether );
		check2( 90 ether, 30 ether, 240 ether );
		rewards[0] = AddedReward(pool2, 75 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 140 ether, 10 ether, 0 ether, 430 ether, 45 ether, 0 ether );
		check2( 90 ether, 30 ether, 240 ether );

		// Bob unstakes 5
		vm.prank(bob);
		liquidity.withdrawLiquidityAndClaim( token2, token3, 2 ether, 0, 0, block.timestamp);
		check1( 140 ether, 8 ether, 0 ether, 430 ether, 36 ether, 0 ether );
		check2( 90 ether, 39 ether, 240 ether );
		rewards[0] = AddedReward(pool2, 74 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 140 ether, 8 ether, 0 ether, 500 ether, 40 ether, 0 ether );
		check2( 90 ether, 39 ether, 240 ether );

		// Bob adds 148
		vm.prank(bob);
		liquidity.addLiquidityAndIncreaseShare( token2, token3, 148 ether, 148 ether, 0, block.timestamp, false );
		check1( 140 ether, 156 ether, 0 ether, 500 ether, 40 ether, 0 ether );
		check2( 90 ether, 39 ether, 240 ether );
		rewards[0] = AddedReward(pool2, 592 ether);
		liquidity.addSALTRewards(rewards);
		vm.warp( block.timestamp + 1 hours );
		check1( 140 ether, 156 ether, 0 ether, 780 ether, 352 ether, 0 ether );
		check2( 90 ether, 39 ether, 240 ether );
    }


    // A unit test where a user tries to add liquidity to a non-whitelisted pool.
    function testAddLiquidityToNonWhitelistedPool() public {
        vm.startPrank(alice);

        // Assuming token4 and token5 form a non-whitelisted pool
        IERC20 token4 = new TestERC20("TEST", 18);
        IERC20 token5 = new TestERC20("TEST", 18);

        uint256 addedAmount1 = 10 ether;
        uint256 addedAmount2 = 20 ether;

        token4.approve(address(liquidity), type(uint256).max);
        token5.approve(address(liquidity), type(uint256).max);


        // Attempt to add liquidity to the non-whitelisted pool
        vm.expectRevert("Invalid pool");
        liquidity.addLiquidityAndIncreaseShare(token4, token5, addedAmount1, addedAmount2, 0 ether, block.timestamp, false);
    }


    // A unit test where a user tries to add liquidity without having enough tokens in their balance.
    function testAddLiquidityWithoutEnoughTokens() public {
        // Alice tries to add more liquidity than she has tokens
        uint256 addedAmount1 = 2000 ether; // Alice has only 1000 ether of each token
        uint256 addedAmount2 = 2000 ether;

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.prank(alice);
        liquidity.addLiquidityAndIncreaseShare(token1, token2, addedAmount1, addedAmount2, 0 ether, block.timestamp, false);
    }


    // A unit test where a user tries to withdraw liquidity from a pool they have not deposited into.
    function testWithdrawLiquidityFromNonDepositedPool() public {
        // Alice attempts to withdraw liquidity from a pool she hasn't deposited into
        vm.expectRevert("Cannot decrease more than existing user share");
        vm.prank(alice);
        liquidity.withdrawLiquidityAndClaim(token2, token3, 10 ether, 0, 0, block.timestamp);
    }


	// A unit test that checks if the liquidity pool respects the minLiquidityReceived parameter.
	function testMinLiquidityReceived() public {
        // Alice tries to add liquidity but sets a high minimum liquidity received
        uint256 addedAmount1 = 10 ether;
        uint256 addedAmount2 = 20 ether;
        uint256 minLiquidityReceived = 1000 ether; // Unattainable minimum liquidity

        vm.expectRevert("Too little liquidity received");
        vm.prank(alice);
        liquidity.addLiquidityAndIncreaseShare(token1, token2, addedAmount1, addedAmount2, minLiquidityReceived, block.timestamp, false);
    }


	// A unit test that defaults to addLiquidity without zapping the tokens to the proper ratio
	function testAddLiquidityWithoutZapping() public {
		// Have alice add liquidity
		vm.startPrank(alice);
		(,, uint256 addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 20 ether, 0 ether, block.timestamp, true );

		uint256 addedAmountA;
		uint256 addedAmountB;

		vm.expectRevert( "Must wait for the cooldown to expire" );
		(addedAmountA, addedAmountB, addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 50 ether, 0 ether, block.timestamp, true );

		vm.warp( block.timestamp + 1 hours );

		(addedAmountA, addedAmountB, addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 10 ether, 50 ether, 0 ether, block.timestamp, true );
		assertEq( addedAmountA, 10 ether );
		assertEq( addedAmountB, 20 ether );

		vm.warp( block.timestamp + 1 hours );

		( addedAmountA, addedAmountB, addedLiquidity) = liquidity.addLiquidityAndIncreaseShare( token1, token2, 50 ether, 20 ether, 0 ether, block.timestamp, true );
		assertEq( addedAmountA, 10 ether );
		assertEq( addedAmountB, 20 ether );
    }


	// A unit test that checks if the contract rejects the dual zap for non-whitelisted pools.
	function testRejectDualZapForNonWhitelistedPools() public {
    	bytes32 nonWhitelistedPool;
    	IERC20 token4;
    	IERC20 token5;

    	// Create new tokens
    	token4 = new TestERC20("TEST", 18);
    	token5 = new TestERC20("TEST", 18);

    	// Get pool ID of non-whitelisted pool
    	(nonWhitelistedPool,) = PoolUtils._poolID(token4, token5);

    	uint256 amountA = 10 ether;
    	uint256 amountB = 20 ether;

    	// Alice has new tokens and approves liquidity to spend them
    	token4.transfer(alice, 1000 ether);
    	token5.transfer(alice, 1000 ether);
    	vm.startPrank(alice);
    	token4.approve(address(liquidity), type(uint256).max);
    	token5.approve(address(liquidity), type(uint256).max);

    	// Should revert while trying to addLiquidityAndIncreaseShare
    	vm.expectRevert("Invalid pool");
    	liquidity.addLiquidityAndIncreaseShare( token4, token5, amountA, amountB, 0 ether, block.timestamp, false );
    }


	// A unit test that checks if the contract correctly reverts excess tokens back to the sender after the addLiquidityAndIncreaseShare() operation.
    function testExcessTokensAreReverted() public {

    	// Create the initial reserve ratio
        token1.approve(address(pools), type(uint256).max);
        token2.approve(address(pools), type(uint256).max);
    	pools.addLiquidity(token1, token2, 100 ether, 100 ether, 0, block.timestamp);

        uint256 initialBalanceToken1Alice = token1.balanceOf( alice );
        uint256 initialBalanceToken2Alice = token2.balanceOf( alice );
        uint256 addedAmount1 = 10 ether;
        uint256 addedAmount2 = 20 ether;

        // Have alice add liquidity with excess tokens
        vm.startPrank(alice);
        token1.approve(address(liquidity), type(uint256).max);
        token2.approve(address(liquidity), type(uint256).max);
        ( uint256 addedAmountA, uint256 addedAmountB,) = liquidity.addLiquidityAndIncreaseShare( token1, token2, addedAmount1, addedAmount2, 0 ether, block.timestamp, true );
		vm.stopPrank();

        // The exact amount of tokens should be deposited in the pool
        assertEq( addedAmountA, addedAmount1, "Incorrect amount of token1 was added to pool" );
        assertEq( addedAmountB, addedAmount1, "Incorrect amount of token2 was added to pool" );

        // Verify that Alice's balance of both tokens has decreased by the amount added to liquidity pool
        assertEq( token1.balanceOf( alice ), initialBalanceToken1Alice - addedAmount1, "Incorrect token1 balance after liquidity addition" );
        assertEq( token2.balanceOf( alice ), initialBalanceToken2Alice - addedAmount1, "Incorrect token2 balance after liquidity addition" );
    }
	}
