// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../dev/Deployment.sol";


contract PoolsConfigTest is Deployment
	{
	IERC20 public token1 = new TestERC20("TEST", 18);
	IERC20 public token2 = new TestERC20("TEST", 18);
	IERC20 public token3 = new TestERC20("TEST", 18);

    uint256 public originalNumWhitelisted;


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();
		}


    function setUp() public
    	{
    	vm.startPrank( address(dao) );

		originalNumWhitelisted = poolsConfig.numberOfWhitelistedPools();

        // Whitelist the pools
        poolsConfig.whitelistPool(pools, token1, token2);
        poolsConfig.whitelistPool(pools, token2, token3);
		vm.stopPrank();
		}


	// A unit test which tests the default values for the contract
	function testConstructor() public {
		assertEq(poolsConfig.maximumWhitelistedPools(), 50, "Incorrect maximumWhitelistedPools");
		assertEq(PoolUtils.STAKED_SALT, bytes32(0), "Incorrect STAKED_SALT value");
	}


	// A unit test that tests maximumWhitelistedPools
	function testMaximumWhitelistedPools() public {
	uint256 numWhitelistedPools = poolsConfig.numberOfWhitelistedPools();

	vm.startPrank( address(dao) );

	uint256 numToAdd = poolsConfig.maximumWhitelistedPools() - numWhitelistedPools;
	for( uint256 i = 0; i < numToAdd; i++ )
		{
		IERC20 tokenA = new TestERC20("TEST", 18);
		IERC20 tokenB = new TestERC20("TEST", 18);

        poolsConfig.whitelistPool(pools, tokenA, tokenB);
		}

	(bytes32 poolID,) = PoolUtils._poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "Maximum number of whitelisted pools already reached" );
    poolsConfig.whitelistPool(pools, token1, token3);
    assertEq( poolsConfig.numberOfWhitelistedPools(), poolsConfig.maximumWhitelistedPools());
    }




	// A unit test that tests the whitelist function with valid input and confirms if the pool is added to the whitelist.
	function testWhitelistValidPool() public {
	vm.startPrank( address(dao) );

	(bytes32 poolID,) = PoolUtils._poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

    poolsConfig.whitelistPool(pools, token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID), "New pool should be valid after whitelisting");
    }


	// A unit test that tests the whitelist function with an invalid input
	function testWhitelistInvalidPool() public {
	vm.startPrank( address(dao) );

	(bytes32 poolID,) = PoolUtils._poolID(token1, token1);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "tokenA and tokenB cannot be the same token" );
    poolsConfig.whitelistPool(pools, token1, token1);

    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should still not be valid");
    }


	// A unit test that tests the unwhitelist function with valid input and ensures the pool is removed from the whitelist.
	function testUnwhitelistValidPool() public {
	vm.startPrank( address(dao) );

    // Whitelist another pool for testing unwhitelist
	(bytes32 poolID,) = PoolUtils._poolID(token1, token3);
    poolsConfig.whitelistPool(pools, token1, token3);

    // Ensure the pool is whitelisted
    assertTrue(poolsConfig.isWhitelisted(poolID));

    // Unwhitelist the test pool
    poolsConfig.unwhitelistPool(pools, token1, token3);

    // Ensure the pool is no longer whitelisted
    assertFalse(poolsConfig.isWhitelisted(poolID));

	// Whitelist again
    poolsConfig.whitelistPool(pools, token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID));
    }


    // A unit test that tests the numberOfWhitelistedPools function and confirms if it returns the correct number of whitelisted pools.
	function testNumberOfWhitelistedPools() public {
	vm.startPrank( address(dao) );

    // Whitelist another pool
    poolsConfig.whitelistPool(pools, token1, token3);

    // Test the numberOfWhitelistedPools function
    uint256 expectedNumberOfWhitelistedPools = originalNumWhitelisted + 3;
    uint256 actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

	// Whitelist the same pool in reverse
    poolsConfig.whitelistPool(pools, token3, token1);

    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

    // Whitelist another pool
    IERC20 token4 = new TestERC20("TEST", 18);

    poolsConfig.whitelistPool(pools, token3, token4);

    expectedNumberOfWhitelistedPools = originalNumWhitelisted + 4;
    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);
    }


    // A unit test that tests the whitelistedPoolAtIndex function and verifies if it returns the correct pool at the given index.
    function testWhitelistedPoolAtIndex() public {
	vm.startPrank( address(dao) );

    bytes32 poolAtIndex0 = poolsConfig.whitelistedPoolAtIndex(originalNumWhitelisted + 0);
    (bytes32 expectedIndex0,) = PoolUtils._poolID(token1, token2);
    assertEq(poolAtIndex0, expectedIndex0, "Pool at index 0 is incorrect");

    bytes32 poolAtIndex1 = poolsConfig.whitelistedPoolAtIndex(originalNumWhitelisted + 1);
    (bytes32 expectedIndex1,) = PoolUtils._poolID(token2, token3);
    assertEq(poolAtIndex1, expectedIndex1, "Pool at index 1 is incorrect");
    }


    // A unit test that tests the isWhitelisted function with valid and invalid pools and confirms if it returns the correct boolean value for each case.
	function testIsValidPool() public {
		vm.startPrank( address(dao) );

        // Whitelist a new pool
    	poolsConfig.whitelistPool(pools, token1, token3);

        // Test valid pools
        (bytes32 pool1,) = PoolUtils._poolID(token1, token2);
        (bytes32 extraPool,) = PoolUtils._poolID(token1, token3);

        assertTrue(poolsConfig.isWhitelisted(pool1), "first pool should be valid");
        assertTrue(poolsConfig.isWhitelisted(extraPool), "extraPool should be valid");
        assertTrue(poolsConfig.isWhitelisted(PoolUtils.STAKED_SALT), "Staked SALT pool should be valid");

        // Test invalid pool
        bytes32 invalidPool = bytes32(uint256(0xDEAD));
        assertFalse(poolsConfig.isWhitelisted(invalidPool), "Invalid pool should not be valid");
    }


	// A unit test that tests the whitelistedPools function and ensures if it returns the correct list of whitelisted pools.
	function testWhitelistedPools() public {
	vm.startPrank( address(dao) );

    // Check initial state
    uint256 initialPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(initialPoolCount, originalNumWhitelisted + 2, "Initial whitelisted pool count is incorrect");

	// Whitelist a new pool
	poolsConfig.whitelistPool(pools, token1, token3);

    // Check new state
    uint256 newPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(newPoolCount, originalNumWhitelisted + 3, "New whitelisted pool count is incorrect");

    // Verify whitelisted pools
	(bytes32 pool1,) = PoolUtils._poolID(token1, token2);
	(bytes32 pool1b,) = PoolUtils._poolID(token2, token1);
	assertEq( pool1, pool1b );

	(bytes32 pool2,) = PoolUtils._poolID(token2, token3);
	(bytes32 extraPool,) = PoolUtils._poolID(token1, token3);

    bytes32[] memory currentPools = poolsConfig.whitelistedPools();
    assertEq(currentPools.length, originalNumWhitelisted + 3, "Whitelisted pools length is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 0], pool1, "First whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 1], pool2, "Second whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 2], extraPool, "Third whitelisted pool is incorrect");
    }


	// A unit test that tests the function of underlyingTokenPair
	function testUnderlyingTokenPair() public {
	vm.startPrank( address(dao) );

	// Whitelist a new pool
	poolsConfig.whitelistPool(pools, token1, token3);

    // Verify already whitelisted pools
	(bytes32 pool1,) = PoolUtils._poolID(token1, token2);
	(bytes32 pool2,) = PoolUtils._poolID(token2, token3);

	// And the newly whitelisted pool
	(bytes32 extraPool,) = PoolUtils._poolID(token1, token3);

	(IERC20 tokenA, IERC20 tokenB) = poolsConfig.underlyingTokenPair(pool1);
	assertEq(address(tokenA), address(token1));
	assertEq(address(tokenB), address(token2));

	(tokenA, tokenB) = poolsConfig.underlyingTokenPair(pool2);
	assertEq(address(tokenA), address(token2));
	assertEq(address(tokenB), address(token3));

	(tokenA, tokenB) = poolsConfig.underlyingTokenPair(extraPool);
	assertEq(address(tokenA), address(token1));
	assertEq(address(tokenB), address(token3));
    }


	// A unit test that tests the tokenHasBeenWhitelisted function when the token has not been whitelisted.
	function testTokenNotWhitelisted() public {
    	vm.startPrank( address(dao) );

    	IERC20 tokenNotWhitelisted = new TestERC20("TEST", 18);

        bool hasWhitelisted = poolsConfig.tokenHasBeenWhitelisted(tokenNotWhitelisted, wbtc, weth);
        assertFalse(hasWhitelisted, "Token should not be whitelisted");
    }


	// A unit test that tests the underlyingTokenPair function when one of the token addresses is 0x0
	function testUnderlyingTokenPairInvalidToken() public {
        vm.startPrank( address(dao) );

        // Generate a pool id with one of the tokens being 0x0
        (bytes32 poolID,) = PoolUtils._poolID(token1, IERC20(address(0)));

        // Expect revert due to invalid pool id
        vm.expectRevert("This poolID does not exist");
        poolsConfig.underlyingTokenPair(poolID);

        vm.stopPrank();
    }



	// A unit test to ensure only owners can change the maximum number of pools that can be whitelisted
    function testChangeMaximumWhitelistedPools() public {
        uint256 initialMaxPools = poolsConfig.maximumWhitelistedPools();

        // Non-owner tries to increase the limit - should revert
        address nonOwner = address(0xDEAD);
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.changeMaximumWhitelistedPools(true);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Non-owner should not be able to increase the limit");

        // Non-owner tries to decrease the limit - should revert
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.changeMaximumWhitelistedPools(false);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Non-owner should not be able to decrease the limit");

        // Owner increases the limit
        vm.startPrank(address(dao));
        poolsConfig.changeMaximumWhitelistedPools(true);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools + 10, "Owner should be able to increase the limit");

        // Owner decreases the limit
        vm.startPrank(address(dao));
        poolsConfig.changeMaximumWhitelistedPools(false);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Owner should be able to decrease the limit");
    }



    // A unit test that tests the unwhitelist function without proper permissions
    function testUnwhitelistPoolWithoutPermissions() public {
    	vm.startPrank( address(dao) );
        (bytes32 poolID,) = PoolUtils._poolID(token1, token3);
        poolsConfig.whitelistPool(pools, token1, token3);
        assertTrue(poolsConfig.isWhitelisted(poolID), "New pool should be valid after whitelisting by owner");
    	 vm.stopPrank();

    	vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.unwhitelistPool(pools, token1, token3);
        assertTrue(poolsConfig.isWhitelisted(poolID), "Whitelisted pool should still be valid after attempted non-owner unwhitelisting");
    }


	// A unit test to confirm that tokenHasBeenWhitelisted returns false for both values if the pair ID doesn't reflect a whitelisted pair
    function testTokenHasBeenWhitelisted() public {
    	IERC20 fakeToken = new TestERC20("FAKE", 18);

    	// Check if the function returns false when the token is not whitelisted
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is not whitelisted");

    	// Whitelist the fake token with WBTC, and check if the function returns true
    	vm.prank(address(dao));
    	poolsConfig.whitelistPool(pools, fakeToken, wbtc);
    	assertTrue(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return true when the token is whitelisted with WBTC");

    	// Unwhitelist the fake token from WBTC, and check if the function returns false now
    	vm.prank(address(dao));
    	poolsConfig.unwhitelistPool(pools, fakeToken, wbtc);
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is unwhitelisted from WBTC");

    	// Whitelist the fake token with WETH, and check if the function returns true
    	vm.prank(address(dao));
    	poolsConfig.whitelistPool(pools, fakeToken, weth);
    	assertTrue(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return true when the token is whitelisted with WETH");

    	// Unwhitelist the fake token from WETH, and check if the function returns false now
    	vm.prank(address(dao));
    	poolsConfig.unwhitelistPool(pools, fakeToken, weth);
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is unwhitelisted from WETH");
    }


	// A unit test that checks that underlyingTokenPair reverts for unwhitelisted poolID
	    function testUnderlyingTokenPairReverts() public {
            vm.expectRevert("This poolID does not exist");
            poolsConfig.underlyingTokenPair(bytes32(0x0));
        }


	// A unit test that tests tokenHasBeenWhitelisted function when tokenA or tokenB is wbtc or weth
	function testTokenHasBeenWhitelisted2() public {

        // Test tokens that have been whitelisted
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(weth, wbtc, weth), "newTokenA should be whitelisted");
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(wbtc, wbtc, weth), "newTokenB should be whitelisted");
    }
}